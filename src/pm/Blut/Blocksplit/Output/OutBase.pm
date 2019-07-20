# abstract class Blut::Blocksplit::Output::OutBase
#
# - ...
# -----------------------------------------------------------------------------
# + Blut::Blocksplit::Output::OutBase()
#
package Blut::Blocksplit::Output::OutBase;

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
    return 0;
}


1;
