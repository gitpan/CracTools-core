#! /usr/bin/perl
#
use Test::More tests => 14;
use CracTools::GFF::Annotation;

my $gff_line = "AB000123\tTwinscan\tCDS\t215991\t216028\t.\t-\t0\tgene_id ".'"AB000123.1"; transcript_id "AB00123.1.2"';

my $gffAnnotation = CracTools::GFF::Annotation->new($gff_line);

ok($gffAnnotation->chr eq 'AB000123','chr()');
ok($gffAnnotation->source eq 'Twinscan','source()');
ok($gffAnnotation->feature eq 'CDS','feature()');
ok($gffAnnotation->start eq 215990,'start()'); # Convert to 0-based coordinate system
ok($gffAnnotation->end eq 216027,'end()'); # Convert to 0-based coordinate system
ok($gffAnnotation->score eq '.','score()');
ok($gffAnnotation->strand == -1,'strand()');
ok($gffAnnotation->phase eq 0,'phase()');
ok($gffAnnotation->gffStrand eq '-', 'gffStrand()');
ok($gffAnnotation->attribute("gene_id") eq "AB000123.1",'attribute() (1)');
ok($gffAnnotation->attribute("transcript_id") eq "AB00123.1.2",'attribute() (2)');
$gffAnnotation->attribute("transcript_id","test");
ok($gffAnnotation->attribute("transcript_id") eq "test",'attribute() (3)');

# Testing GFF3
my $gff3_line = "HSCHR6_MHC_MANN\tEnsembl_CORE\texon\t30051790\t30051922\t.\t-\t.\tID=ENSE00002706393;Parent=ENST00000578939";
my $gff3Annotation = CracTools::GFF::Annotation->new($gff3_line,'gff3');

ok($gff3Annotation->attribute("ID") eq 'ENSE00002706393', 'GFF3 attributes parsing (1)');
ok($gff3Annotation->attribute("Parent") eq 'ENST00000578939', 'GFF3 attributes parsing (2)');
