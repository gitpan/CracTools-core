#! /usr/bin/perl
#
use strict;
use warnings;

use Getopt::Long; # Get options
use Pod::Usage;   # Printing pod documentation in terminal
use File::Temp;   # Generate temporary files and directories
use File::Spec;   # Transform relative path to abs path

use CracTools::Config;


if(@ARGV  < 1) {
  die "Usage: generateReport.pl report.Rnw --options ...";
}

# Open configuration file
CracTools::Config::LoadConfig();

my $report_file = shift;

open(IN,$report_file) or die("Cannot open $report_file");

my %options;
while(<IN>) {
  my($option_name,$option_desc) = $_ =~ /##(\S+),\"(.*?)\"/;
  if(defined $option_name && defined $option_desc) {
    $options{$option_name} = {desc => $option_desc, type => 'mandatory'};
  }
}
close(IN);

# Add options for output
my $output_name = "o|output=s";
$options{$output_name} = {desc => "Output file", type => "optional"};

# Add chunk dir option
my $chunks_dir_name = "chunks-dir=s";
$options{$chunks_dir_name} = {desc => "R-report chunks directory", type => "optional"};

sub printUsage {
  print STDERR "Usage: generateReport.pl report.Rnw";
  foreach my $opt (keys %options) {
    print STDERR " --".$opt;
  }
  print STDERR "\n";
  foreach my $opt (keys %options) {
    print STDERR "\t".$opt.": ".$options{$opt}->{desc}."\n";
  }
}

# Set get opt hash
my %getOpt_hash;
foreach my $opt (keys %options) {
  $options{$opt}->{value} = undef;
  $getOpt_hash{$opt} = \$options{$opt}->{value};
}

# Retrieve options using Getopt::Long
GetOptions(%getOpt_hash);

foreach my $opt (keys %options) {
  # Check if mandatory option is missing
  if(!defined $options{$opt}->{value} && $options{$opt}->{type} eq 'mandatory') {
    print STDERR "Missing option: $opt\n";
    printUsage();
    exit 1;
  }
  # if option is a file, transform relative file path to absolute
  if(defined $options{$opt}->{value} && -e $options{$opt}->{value}) {
    $options{$opt}->{value} = File::Spec->rel2abs($options{$opt}->{value});
  }
}

my $chunks_dir = $options{$chunks_dir_name}->{value};
$chunks_dir = CracTools::Config::getConfVar('REPORT_CHUNKS_DIR') unless defined $chunks_dir;
die "Missing REPORT_CHUNKS_DIR in conf file" if !defined $chunks_dir;

my $report_fulfilled = File::Temp->new();
open(IN,$report_file) or die("Cannot open $report_file");

while(<IN>) {
  my($option_name) = $_ =~ /##(\S+),/;
  if(defined $option_name) {
    my $value = $options{$option_name}->{value};
    $_ =~ s/##.*$/\"$value\"/;
  } 
  
  # Set chunk directory
  $_ =~ s/child=\'(\S+?)\'/child=\'$chunks_dir\/$1\'/;

  print $report_fulfilled $_;
}
close(IN);
close($report_fulfilled);

#print("knit ".$report_fulfilled->filename);
my $tex_output = $options{$output_name}->{value}.".tex";
system("knit ".$report_fulfilled->filename." -o $tex_output");


# Open tex output to insert CHUNKS dir, if a chunks contains relatives links

open(IN,$tex_output) or die("Cannot open $tex_output");
open(OUT,">$tex_output.tmp") or die("Cannot open $tex_output.tmp");

while(<IN>) {
  # Set chunk directory
  $_ =~ s/\$CHUNKS_DIR(\S+?)/$chunks_dir\/$1/;
  print OUT $_;
}
close(IN);
close(OUT);

system("mv $tex_output.tmp $tex_output");

