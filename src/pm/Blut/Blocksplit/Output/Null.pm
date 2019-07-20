# class Blut::Blocksplit::Output::Null
#
# - ...
# -----------------------------------------------------------------------------
# + Blut::Blocksplit::Output::Null()
#
package Blut::Blocksplit::Output::Null;

use strict;
use warnings;

use parent 'Blut::Blocksplit::Output::Base';

our $VERSION = 0.1;


sub new {
    my $class = shift;
    my $self  = $class->SUPER::new();

    return bless $self, $class;
}


sub is_null {
    return 1;
}


sub add {
    return 1;
}


1;
