INSTALL_DIR=$1
perl Makefile.PL PREFIX=$INSTALL_DIR LIB=$INSTALL_DIR/lib/perl5 && make && make install
