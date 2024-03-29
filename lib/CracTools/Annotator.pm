###############################################################################
#                                                                             #
#    Copyright © 2012-2013 -- IRB/INSERM                                      #
#                            (Institut de Recherche en Biothérapie /          #
#                             Institut National de la Santé et de la          #
#                             Recherche Médicale)                             #
#                                                                             #
#  Auteurs/Authors:  Jerôme AUDOUX <jerome.audoux@univ-montp2.fr>             #
#                    Nicolas PHILIPPE <nicolas.philippe@inserm.fr>            #
#                                                                             #
#  -------------------------------------------------------------------------  #
#                                                                             #
#  Ce fichier fait partie de la suite CracTools qui contient plusieurs pipeline# 
#  intégrés permettant de traiter les évênements biologiques présents dans du #
#  RNA-Seq. Les CracTools travaillent à partir d'un fichier SAM de CRAC et d'un# 
#  fichier d'annotation au format GFF3.                                       #
#                                                                             #
#  Ce logiciel est régi  par la licence CeCILL  soumise au droit français et  #
#  respectant les principes  de diffusion des logiciels libres.  Vous pouvez  #
#  utiliser, modifier et/ou redistribuer ce programme sous les conditions de  #
#  la licence CeCILL  telle que diffusée par le CEA,  le CNRS et l'INRIA sur  #
#  le site "http://www.cecill.info".                                          #
#                                                                             #
#  En contrepartie de l'accessibilité au code source et des droits de copie,  #
#  de modification et de redistribution accordés par cette licence, il n'est  #
#  offert aux utilisateurs qu'une garantie limitée.  Pour les mêmes raisons,  #
#  seule une responsabilité  restreinte pèse  sur l'auteur du programme,  le  #
#  titulaire des droits patrimoniaux et les concédants successifs.            #
#                                                                             #
#  À  cet égard  l'attention de  l'utilisateur est  attirée sur  les risques  #
#  associés  au chargement,  à  l'utilisation,  à  la modification  et/ou au  #
#  développement  et à la reproduction du  logiciel par  l'utilisateur étant  #
#  donné  sa spécificité  de logiciel libre,  qui peut le rendre  complexe à  #
#  manipuler et qui le réserve donc à des développeurs et des professionnels  #
#  avertis  possédant  des  connaissances  informatiques  approfondies.  Les  #
#  utilisateurs  sont donc  invités  à  charger  et  tester  l'adéquation du  #
#  logiciel  à leurs besoins  dans des conditions  permettant  d'assurer  la  #
#  sécurité de leurs systêmes et ou de leurs données et,  plus généralement,  #
#  à l'utiliser et l'exploiter dans les mêmes conditions de sécurité.         #
#                                                                             #
#  Le fait  que vous puissiez accéder  à cet en-tête signifie  que vous avez  #
#  pris connaissance  de la licence CeCILL,  et que vous en avez accepté les  #
#  termes.                                                                    #
#                                                                             #
#  -------------------------------------------------------------------------  #
#                                                                             #
#  This file is part of the CracTools which provide several integrated        #
#  pipeline to analyze biological events present in RNA-Seq data. CracTools   #
#  work on a SAM file generated by CRAC and an annotation file in GFF3 format.#
#                                                                             #
#  This software is governed by the CeCILL license under French law and       #
#  abiding by the rules of distribution of free software. You can use,        #
#  modify and/ or redistribute the software under the terms of the CeCILL     #
#  license as circulated by CEA, CNRS and INRIA at the following URL          #
#  "http://www.cecill.info".                                                  #
#                                                                             #
#  As a counterpart to the access to the source code and rights to copy,      #
#  modify and redistribute granted by the license, users are provided only    #
#  with a limited warranty and the software's author, the holder of the       #
#  economic rights, and the successive licensors have only limited            #
#  liability.                                                                 #
#                                                                             #
#  In this respect, the user's attention is drawn to the risks associated     #
#  with loading, using, modifying and/or developing or reproducing the        #
#  software by the user in light of its specific status of free software,     #
#  that may mean that it is complicated to manipulate, and that also          #
#  therefore means that it is reserved for developers and experienced         #
#  professionals having in-depth computer knowledge. Users are therefore      #
#  encouraged to load and test the software's suitability as regards their    #
#  requirements in conditions enabling the security of their systems and/or   #
#  data to be ensured and, more generally, to use and operate it in the same  #
#  conditions as regards security.                                            #
#                                                                             #
#  The fact that you are presently reading this means that you have had       #
#  knowledge of the CeCILL license and that you accept its terms.             #
#                                                                             #
###############################################################################

package CracTools::Annotator;
{
  $CracTools::Annotator::DIST = 'CracTools-core';
}
# ABSTRACT: Generic annotation base on CracTools::GFF::Query
$CracTools::Annotator::VERSION = '1.031';
use strict;
use warnings;

use Carp;
use Data::Dumper;
use CracTools::GFF::Annotation;
#use CracTools::GFF::Query;
use CracTools::Interval::Query;
use CracTools::Const;


sub new {
  my $class = shift;
  my $gff_file = shift;

  if(!defined $gff_file) {
    croak "Missing GFF file argument in CracTools::Annotator constructor";
  }

  my $self = bless {
    gff_file => $gff_file,
  }, $class;

  $self->_init();

  return $self;
}


sub foundGene {
  my $self = shift;
  my ($chr,$pos_start,$pos_end,$strand) = @_;
  my @candidates = $self->getAnnotationCandidates($chr,$pos_start,$pos_end,$strand);
  return @candidates > 0;
}


sub foundSameGene {
  my $self = shift;
  my ($chr,$pos_start1,$pos_end1,$pos_start2,$pos_end2,$strand) = @_;
  my @candidates1 = $self->getAnnotationCandidates($chr,$pos_start1,$pos_end1,$strand);
  my @candidates2 = $self->getAnnotationCandidates($chr,$pos_start2,$pos_end2,$strand);
  my $found_same_gene = 0;
  my @genes1;
  my @genes2;
  foreach my $candi1 (@candidates1) {
    if(defined $candi1->{gene}) {
      push @genes1,$candi1->{gene}->attribute('ID');
    }
  }
  foreach my $candi2 (@candidates2) {
    if(defined $candi2->{gene}) {
      push @genes2,$candi2->{gene}->attribute('ID');
    }
  }
  foreach my $gene_id (@genes1) {
    foreach (@genes2) {
      if($gene_id eq $_) {
        $found_same_gene = 1;
        last;
      }
    }
    last if $found_same_gene == 1;
  }
  return $found_same_gene;
}


sub getBestAnnotationCandidate {
  my $self = shift;
  my ($chr,$pos_start,$pos_end,$strand,$prioritySub) = @_;

  $prioritySub = \&getCandidatePriorityDefault unless defined $prioritySub;

  my @candidates = $self->getAnnotationCandidates($chr,$pos_start,$pos_end,$strand);
  my ($best_priority,$best_candidate,$best_type);
  foreach my $candi (@candidates) {
    my ($priority,$type) = $prioritySub->($pos_start,$pos_end,$candi);
    if($priority != -1) {
      if(!defined $best_priority || $priority < $best_priority) {
        $best_priority = $priority;
        $best_candidate = $candi;
        $best_type = $type;
      }
    }
  }
  return $best_candidate,$best_priority,$best_type;
}


sub getAnnotationCandidates {
  my $self = shift;
  my ($chr,$pos_start,$pos_end,$strand) = @_;

  # get GFF annotations that overlap the region to annotate
  my $annotations = $self->{gff_query}->fetchByRegion($chr,$pos_start,$pos_end,$strand);

  my %annot_hash = ();
  my @candidates = ();

  # Construct annotation hash with annot ID as key
  foreach my $annot_line (@{$annotations}) {
    my $annot = CracTools::GFF::Annotation->new($annot_line,'gff3');
    $annot_hash{$annot->attribute('ID')} = $annot;
  }

  # Find root in annotation tree
  foreach my $annot_id (keys %annot_hash) {
    my @parents = $annot_hash{$annot_id}->parents;

    # we have foud a root, lets constructs candidates
    if(scalar @parents == 0) {
      push @candidates, _constructCandidate($annot_id,my $new_candidate,\%annot_hash);
    }
  }

  return @candidates;
}


sub getCandidatePriorityDefault {
  my ($pos_start,$pos_end,$candidate) = @_;
  my ($priority,$type) = (-1,'');
  my ($mRNA,$exon) = ($candidate->{mRNA},$candidate->{exon});
  if(defined $mRNA) {
    if($mRNA->attribute('type') =~ /protein_coding/i) {
      if(defined $exon) {
        if($exon->start > $pos_start || $exon->end < $pos_end) {
          $priority = 1;
          if(defined $candidate->{three}) {
            $type = '3PRIM_UTR';
          } elsif(defined $candidate->{five}) {
            $type = '5PRIM_UTR';
          } elsif(defined $candidate->{cds}) {
            $type = 'CDS';
          } else {
            $type = 'EXON';
          }
        } else {
          $priority = 2;
          $type = 'INXON';
        }
      }
    } else {
      if(defined $exon) {
        if($exon->start > $pos_start || $exon->end < $pos_end) {
          $priority = 3;
          $type = 'NON_CODING';
        }
      }
    }
  }
  return ($priority,$type);
}


sub _init {
  my $self = shift;

  # Create a GFF file to query exons
  my $gff_query = CracTools::Interval::Query->new(file => $self->{gff_file}, type => 'gff');
  $self->{gff_query} = $gff_query;

}


sub _constructCandidate {
  my ($annot_id,$candidate,$annot_hash) = @_;
  $candidate->{$annot_hash->{$annot_id}->feature} = $annot_hash->{$annot_id};
  foreach my $annot (values %{$annot_hash}) {
    my @parents = $annot->parents;
    foreach my $parent (@parents) {
      if($parent eq $annot_id) {
        _constructCandidate($annot->attribute('ID'),$candidate,$annot_hash);
      }
    }
  }
  return $candidate;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

CracTools::Annotator - Generic annotation base on CracTools::GFF::Query

=head1 VERSION

version 1.031

=head1 METHODS

=head2 new

  Arg [1] : String - $gff_file
            GFF file to perform annotation

  Example     : my $annotation = CracTools::GFF::Annotation->new($gff_line);
  Description : Create a new CracTools::GFF::Annotation object
                If a gff line is passed in argument, the line will be parsed
                and loaded.
  ReturnType  : CracTools::GFF::Query
  Exceptions  : none

=head2 foundGene

  Arg [1] : String - chr
  Arg [2] : String - pos_start
  Arg [3] : String - pos_end
  Arg [4] : String - strand

  Description : Return true if there is an exon of a gene is this interval
  ReturnType  : Boolean
  Exceptions  : none

=head2 foundSameGene

  Arg [1] : String - chr
  Arg [2] : String - pos_start1
  Arg [3] : String - pos_end1
  Arg [4] : String - pos_start2
  Arg [5] : String - pos_end1
  Arg [6] : String - strand

  Description : Return true if a gene is the same gene is found is the two intervals.
  ReturnType  : Boolean
  Exceptions  : none

=head2 getBestAnnotationCandidate

  Arg [1] : String - chr
  Arg [2] : String - pos_start
  Arg [3] : String - pos_end
  Arg [4] : String - strand
  Arg [5] : (Optional) Subroutine - see C<getCandidatePriorityDefault> for more details

  Description : Return best annotation candidate according to the priorities given
                by the subroutine in argument.
  ReturnType  : Hash( feature_name => CracTools::GFF::Annotation, ...), Int(priority), String(type)

=head2 getAnnotationCandidates

  Arg [1] : String - chr
  Arg [2] : String - pos_start
  Arg [3] : String - pos_end
  Arg [4] : String - strand

  Description : Return an array with all annotation candidates overlapping the
                chromosomic region.
  ReturnType  : Array of Hash( feature_name => CracTools::GFF::Annotation, ...)

=head2 getCandidatePriorityDefault

  Arg [1] : String - pos_start
  Arg [2] : String - pos_end
  Arg [3] : hash - candidate

  Description : Default method used to give a priority to a candidate.
                You can create your own priority method to fit your specific need
                for selecting the best annotation.
                The best priority is 0. A priority of -1 means that this candidate
                should be avoided.
  ReturnType  : Array ($priority,$type) where $priority is an integer and $type a string

=head1 PRIVATE METHODS

=head2 _init

  Description : init method, load GFF annotation into a
                CracTools::GFF::Query object.

=head2 _constructCandidate

  Arg [1] : String - annot_id
  Arg [2] : Hash ref - candidate
            Since this method is recursive, this is the object that
            we are constructing
  Arg [3] : Hash ref - annot_hash
            annot_hash is a hash reference where keys are annotion IDs
            and values are CracTools::GFF::Annotation objects.

  Description : _constructCandidate is a recursive method that build a
                candidate hash.
  ReturnType  : Candidate Hash ref where keys are GFF features and
                values are CracTools::GFF::Annotation objects :
                { feature => CracTools::GFF::Annotation, ...}

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
