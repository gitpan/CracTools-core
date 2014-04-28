use strict;
use warnings;

use Test::More tests => 2;
use CracTools::Utils;

is(CracTools::Utils::reverseComplement("ATGCAG"), "CTGCAT", 'reverseComplement()');
is(CracTools::Utils::reverse_tab("1,2,0,1"), "1,0,2,1", 'reverse_tab()');
