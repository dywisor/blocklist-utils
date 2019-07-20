# abstract class Blut::Blocksplit::Output::Base
#
# - ...
# -----------------------------------------------------------------------------
# + Blut::Blocksplit::Output::Base()
#
package Blut::Blocksplit::Output::Base;

use strict;
use warnings;

our $VERSION = 0.1;


sub new {
    my $class = shift;
    my $self  = {};

    return bless $self, $class;
}


sub is_null {
    die "method not implemented: is_null()\n";
}


sub add {
    die "method not implemented: add()\n";
}
