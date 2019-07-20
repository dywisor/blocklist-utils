# abstract class Blut::Blocksplit::Output::File
#
# - ...
# -----------------------------------------------------------------------------
# + Blut::Blocksplit::Output::File ( fh )
#
package Blut::Blocksplit::Output::File;

use strict;
use warnings;

use parent 'Blut::Blocksplit::Output::FileBase';

our $VERSION = 0.1;


sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(shift);

    return bless $self, $class;
}


sub add {
    my ( $self, $arg ) = @_;

    printf {$self->{_fh}} "%s\n", $arg;
    return 1;
}


1;
