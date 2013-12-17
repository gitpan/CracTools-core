#! /usr/bin/perl
#
use strict;
use warnings;
use Test::More tests => 3;
use CracTools::Annotator;
use File::Temp;
use Data::Dumper;

my $gff = "1\tEnsembl_CORE\texon\t12\t42\t.\t+\t.\tID=ENSE00002706393;Parent=ENST00000578939\n".
          "1\tEnsembl_CORE\tcds\t12\t42\t.\t+\t.\tID=ENST00000578939.cds;Parent=ENST00000578939\n".
          "1\tEnsembl_CORE\tmRNA\t12\t42\t.\t+\t.\tID=ENST00000578939;Parent=ENSG00000266142;Exons_NB=1;type=protein_coding\n".
          "1\tEnsembl_CORE\tgene\t12\t42\t.\t+\t.\tID=ENSG00000266142;Name=TOTO;Transcripts_NB=1\n".
          "1\tEnsembl_CORE\tgene\t12\t42\t.\t+\t.\tID=ENSG00000266143;Name=TOTO2;Transcripts_NB=1\n";

my $gff_file = new File::Temp( SUFFIX => '.gff', UNLINK => 1);
print $gff_file $gff;
close $gff_file;

my $annotator = CracTools::Annotator->new($gff_file);

my @candidates = $annotator->getAnnotationCandidates(1,11,41,1); # Convert to 0-based coordinate system
#print Dumper(\@candidates);
my ($annot,$priority,$type) = $annotator->getBestAnnotationCandidate(1,12,42,1);
is($annot->{gene}->attribute('Name'),'TOTO','getBestAnnotationCandidate');
is($annot->{cds}->attribute('ID'),'ENST00000578939.cds','getBestAnnotationCandidate');
#my @annot = $annotator->getAnnotation(1,12,42,1,\&CracTools::Annotator::getCandidatePriorityDefault);
ok($annotator->foundSameGene(1,12,42,12,42,1)  ,'foundSameGene');
#my ($candidates_ref,$genes_ref) = $annotator->_getAnnotationCandidates(1,11,41,1); # Convert to 0-based coordinate system
#ok(defined $candidates_ref->{ENST00000578939},'_getAnnotationCandidates (1)');
#is(scalar values %{$candidates_ref},1,'_getAnnotationCandidates (2)');
#is(scalar values %{$genes_ref},1,'_getAnnotationCandidates (3)');
#is($candidates_ref->{ENST00000578939}{flags},49,'_getAnnotationCandidates (4)');
#is($annotator->_getCandidateType($candidates_ref->{ENST00000578939}),'CDS','_getCandidateType'); 
#
#my $annot = $annotator->getAnnotation(1,12,42,1);
#is($annot->{hugo},'TOTO','getAnnotation (1)');
