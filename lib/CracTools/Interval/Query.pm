package CracTools::Interval::Query;
{
  $CracTools::Interval::Query::DIST = 'CracTools-core';
}
# ABSTRACT: Query intervals in various type of files
#
$CracTools::Interval::Query::VERSION = '1.031';
use strict;
use warnings;

use CracTools::Utils;
use Set::IntervalTree 0.10;
use Fcntl qw( SEEK_SET );
use Carp;


sub new {
  my $class = shift;

  my %args = @_;

  my $file = $args{file};
  croak "Missing file" unless defined $file;

  my $get_interval_sub = $args{get_interval_sub};

  my $header_skip = "#";
  $header_skip = $args{header_skip} if defined $args{header_skip};

  if(!defined $get_interval_sub) {
    my $type = $args{type};
    croak "Missing type" unless defined $type;
    if($type =~ /gff/i) {
      $get_interval_sub = \&_getIntervalsFromGFFLine;
    } elsif($type =~ /sam/i) {
      $get_interval_sub = \&_getIntervalsFromSAMLine;
      $header_skip = "@";
    } elsif($type =~ /bed/i) {
      $get_interval_sub = \&_getIntervalsFromBEDLine;
      $header_skip = "track";
    } else {
      croak "Undefined type ($type)";
    }
  }

  my $self = bless {
    get_interval_sub => $get_interval_sub,
    header_skip => $header_skip,
    file => $file,
  }, $class;

  $self->_init();

  return $self;
}


sub fetchByRegion {
  my ($self,$chr,$pos_start,$pos_end,$strand,$windowed) = @_;

  my $interval_tree = $self->_getIntervalTree($chr,$strand);
  my $lines = [];
  
  if(defined $interval_tree) {
    my $seek_values;
    if(defined $windowed && $windowed) {
      # pos_end +1 because Interval tree use [a,b) intervals
      $seek_values = $interval_tree->fetch_window($pos_start,$pos_end+1);
    } else {
      # pos_end +1 because Interval tree use [a,b) intervals
      $seek_values = $interval_tree->fetch($pos_start,$pos_end+1);
    }

    $lines = $self->_getLines($seek_values);
  }

  return $lines;
}


sub fetchByLocation {
  my ($self,$chr,$position,$strand) = @_;
  return $self->fetchByRegion($chr,$position,$position,$strand);
}


sub fetchNearestDown {
  my ($self,$chr,$position,$strand) = @_;

  my $interval_tree = $self->_getIntervalTree($chr,$strand);
  my $line;
  
  if(defined $interval_tree) {
    my $seek_pos = $interval_tree->fetch_nearest_down($position);
    $line = $self->_getLine($seek_pos) if defined $seek_pos;
  }
  return $line;
}


sub fetchAllNearestDown {
  my ($self,$chr,$position,$strand) = @_;
  my @lines;

  my $nearest_down = $self->fetchNearestDown($chr,$position,$strand); 

  if(defined $nearest_down) {
    my $intervals = $self->_getIntervals($nearest_down);
    # We try to determinate wich interval was matched
    my $best_interval;
    foreach my $i (@$intervals) {
      $i->{strand} = 1 unless defined $i->{strand};
      if ( $i->{high}    <  $position && 
           $i->{seqname} eq $chr      && 
           $i->{strand}  eq $strand ) {
        if(!defined $best_interval) {
          $best_interval = $i;
        } elsif ($best_interval->{high} < $i->{high}) {
          $best_interval = $i;
        }
      }
    }
    # We return all lines that belong to this
    if(defined $best_interval) {
      my $overlapping_lines = $self->fetchByLocation($chr,$best_interval->{high},$strand);
      foreach my $line (@$overlapping_lines) {
        my $intervals = $self->_getIntervals($line);
        foreach my $i (@$intervals) {
          if($i->{high}     ==  $best_interval->{high} && 
             $i->{seqname}  eq  $chr && 
             $i->{strand}   eq  $strand) {
            push(@lines,$line);
            last;
          }
        }
      }
    }
  }
  return \@lines;
}


sub fetchNearestUp {
  my ($self,$chr,$position,$strand) = @_;

  my $interval_tree = $self->_getIntervalTree($chr,$strand);
  my $line;
  
  if(defined $interval_tree) {
    my $seek_pos = $interval_tree->fetch_nearest_up($position);
    $line = $self->_getLine($seek_pos) if defined $seek_pos;
  }
  return $line;
}


sub fetchAllNearestUp {
  my ($self,$chr,$position,$strand) = @_;
  my @lines;

  my $nearest_down = $self->fetchNearestUp($chr,$position,$strand); 

  if(defined $nearest_down) {
    my $intervals = $self->_getIntervals($nearest_down);
    # We try to determinate wich interval was matched
    my $best_interval;
    foreach my $i (@$intervals) {
      $i->{strand} = 1 unless defined $i->{strand};
      if ( $i->{low}    >  $position && 
           $i->{seqname} eq $chr      && 
           $i->{strand}  eq $strand ) {
        if(!defined $best_interval) {
          $best_interval = $i;
        } elsif ($best_interval->{low} > $i->{low}) {
          $best_interval = $i;
        }
      }
    }
    # We return all lines that belong to this
    if(defined $best_interval) {
      my $overlapping_lines = $self->fetchByLocation($chr,$best_interval->{low},$strand);
      foreach my $line (@$overlapping_lines) {
        my $intervals = $self->_getIntervals($line);
        foreach my $i (@$intervals) {
          if($i->{low}     ==  $best_interval->{low} && 
             $i->{seqname}  eq  $chr && 
             $i->{strand}   eq  $strand) {
            push(@lines,$line);
            last;
          }
        }
      }
    }
  }
  return \@lines;
}


sub _getIntervals {
  my ($self,$line) = @_;
  my $intervals = $self->{get_interval_sub}->($line);
  foreach (@$intervals) {$_->{strand} = 1 if !defined $_{strand};}
  return $intervals;
}


sub _getLine {
  my ($self,$seek_pos) = @_;
  my $fh = $self->{filehandle};
  seek($fh,$seek_pos,SEEK_SET);
  my $line = <$fh>;
  chomp($line);
  return $line;
}


sub _getLines {
  my ($self,$seek_pos) = @_;
  my @lines;
  my $fh = $self->{filehandle};
  foreach (@$seek_pos) {
    seek($fh,$_,SEEK_SET);
    my $line = <$fh>;
    chomp($line);
    push(@lines,$line);
  }
  return \@lines;
}


sub _getIntervalTree {
  my ($self,$chr,$strand) = @_;
  return $self->{interval_trees}{_getIntervalTreeKey($chr,$strand)};
}

sub _init {
  my $self = shift;

  open(my $fh ,$self->{file}) or die ("Cannot open file ".$self->{file});

  my $curr_pos = tell($fh);
  my $header_line = 1;
  my %interval_trees;

  while(<$fh>) {

    # skip headers
    if($header_line) {
      if($_ =~ /^$self->{header_skip}/) {
        next;
      } else {
        $header_line = 0;
      }
    }

    my $pos = $curr_pos;
    my $intervals = $self->{get_interval_sub}->($_);

    foreach my $i (@$intervals) {
      if(defined $i->{low} && defined $i->{high} && defined $i->{seqname}) {

        # Add strand to default if not defined
        $i->{strand} = 1 unless defined $i->{strand};

        my $key = _getIntervalTreeKey($i->{seqname},$i->{strand});
        if(!defined $interval_trees{$key}) {
          $interval_trees{$key} = Set::IntervalTree->new;
        }

        # high +1 beacause Interval tree use [a,b) intervals
        $interval_trees{$key}->insert($pos,$i->{low},$i->{high}+1);
        #$interval_trees{$key}->insert({seek => $pos, low => $i->{low}, high => $i->{high}},$i->{low},$i->{high}+1);
      }
    }

    $curr_pos = tell($fh);
  }

  $self->{filehandle} = $fh;
  $self->{interval_trees} = \%interval_trees;
}



sub _getIntervalsFromGFFLine {
  my $line = shift;
  my @fields = split("\t",$line,8);
  return [{ seqname => $fields[0],
            low => $fields[3], 
            high => $fields[4],
            strand => CracTools::Utils::convertStrand($fields[6]),
          }];
}

sub _getIntervalsFromSAMLine {
  my $line = shift;
  my @fields = split("\t",$line,7);
  my $strand = 1;
  if($fields[1] & 16) {
    $strand = -1;
  }
  my $low = $fields[3];
  my $high = $low;
  my $intervals = [];
  my $i = 0;
  my @chunks = $fields[5] =~ /(\d+\D)/g;
  foreach (@chunks) {
    my ($nb,$op) = $_ =~ /(\d+)(\D)/;
    if( $op eq 'N' || $op eq 'D' ) {
      $intervals->[$i] = { seqname => $fields[2], 
                           low => $low, 
                           high =>$high,
                           strand => $strand,
                         };
      $i++;
      $low = $high + $nb;
      $high = $low;
    } elsif ($op ne 'S' || $op ne 'H' || $op ne 'I') {
      $high += $nb;
    }
  }
  # Add the last chunk
  $intervals->[$i] = { seqname => $fields[2], 
                       low => $low, 
                       high =>$high,
                       strand => $strand,
                     };
  return $intervals;
}


sub _getIntervalsFromBEDLine {
  my $line = shift;
  my @fields = split("\t",$line,13);
  if(@fields < 12) {
    return [{ seqname => $fields[0], low => $fields[1]+1, high => $fields[2] }];
  } else {
    my $intervals  = [];
    my $low = $fields[1];
    my $high;
    my @block_size = split(',',$fields[10]);
    my @block_start = split(',',$fields[11]);
    for(my $i = 0; $i < $fields[9]; $i++) {
      $low += $block_start[$i]; 
      $high = $low + $block_size[$i];
      $intervals->[$i] = { seqname => $fields[0],
                           low => $low + 1, 
                           high => $high,
                           strand => CracTools::Utils::convertStrand($fields[5]),
                         };
    }
    return $intervals;
  }
}

sub _getIntervalTreeKey {
  my ($chr,$strand) = @_;
  return "$chr"."@"."$strand";
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

CracTools::Interval::Query - Query intervals in various type of files

=head1 VERSION

version 1.031

=head2 new

  Arg [1] : String - GFF file

  Example     : my $gffQuery = CracTools::GFF::Query->new('annotations.gff');
  Description : Create a new GFF Query object
  ReturnType  : CracTools::GFF::Query
  Exceptions  : none

=head2 fetchByRegion

  Arg [1] : String $seq_region_name
            The name of the sequence region that the slice will be
            created on.
  Arg [2] : int $start
            The start of the slice on the sequence region
  Arg [3] : int $end
            The end of the slice on the sequence region
  Arg [4] : int $strand
            The orientation of the slice on the sequence region
  Arg [5] : (Optional) Boolean $windowed
            Only return lines whose intervals are completely contained
            if the slide.

  Example     : my @lines = $IntervalQuery->fetchByRegion('1',298345,309209,'+');
  Description : Retrives lines that belong to the region.
  ReturnType  : Reference to an Array of strings
  Exceptions  : none

=head2 fetchByLocation

  Arg [1] : String $seq_region_name
            The name of the sequence region that the slice will be
            created on.
  Arg [2] : int $position
            Location to look for
  Arg [3] : int $strand
            The orientation of the slice on the sequence region

  Example     : my @lines = $intervalQuery->fetchByLocation('1',298345,'+');
  Description : Retrives lines that overlapped the given location.
  ReturnType  : Reference to an Array of strings
  Exceptions  : none

=head2 fetchNearestDown

Search for the closest interval in downstream that does not contain the query
and returns the line associated to this interval. 

=head2 fetchAllNearestDown

Search for the closest intervals in downstream that does not contain the query
and returns an array reference of lines associated to these intervals. 

=head2 fetchNearestUp

Search for the closest interval in downstream that does not contain the query
and returns the line associated to this interval. 

=head2 fetchAllNearestUp

Search for the closest intervals in downstream that does not contain the query
and returns an array reference of lines associated to these intervals. 

=head2 _getIntervals

Return an array reference of intervals associated with the line.

Interval structure is described by get_interval_sub

=head2 _getLine

=head2 _getLines

=head2 _getIntervalTree 

  $self->getIntervalTree($chr,$strand);

Return the interval tree reference for the chromosome and strand

=head2 _getIntervalsFrom<FORMAT>Line

Interval must be :
1-base coordinate system
Closed intervals

=head2 _getIntervalsFromBEDLine

We transform BED annotation postions to base-1 positions, and closed intervals

=head1 AUTHORS

=over 4

=item *

Nicolas PHILIPPE <nicolas.philippe@inserm.fr>

=item *

Jérôme AUDOUX <jaudoux@cpan.org>

=back

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2014 by IRB/INSERM (Institut de Recherche en Biothérapie / Institut National de la Santé et de la Recherche Médicale).

This is free software, licensed under:

  CeCILL FREE SOFTWARE LICENSE AGREEMENT, Version 2.1 dated 2013-06-21

=cut
