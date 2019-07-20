# abstract class Blut::Blocksplit::Output::FileBase
#
# - ...
# -----------------------------------------------------------------------------
# + Blut::Blocksplit::Output::FileBase ( fh )
#
package Blut::Blocksplit::Output::FileBase;

use strict;
use warnings;

use parent 'Blut::Blocksplit::Output::OutBase';

our $VERSION = 0.1;


sub new {
    my $class = shift;
    my $self  = $class->SUPER::new();

    $self->{_fh} = shift;

    return bless $self, $class;
}


1;
