use strict;
use warnings;
use Test::More;

eval "use Test::Prereq";
plan skip_all => "Test::Prereq required to test dependencies" if $@;


# Bio::EnsEMBL::ApiVersion and Bio::EnsEMBL::ApiVersion are only required
# for buildGFF3FromEnsembl.pl script. It is not supposed to block the
# installation process
my @skip_modules = ("Bio::EnsEMBL::ApiVersion","Bio::EnsEMBL::Registry");

prereq_ok(undef,undef,\@skip_modules);
