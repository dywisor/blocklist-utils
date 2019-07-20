# abstract class Blut::Blocksplit::Output::TaggedFile
#
# - ...
# -----------------------------------------------------------------------------
# + Blut::Blocksplit::Output::TaggedFile ( fh, tag )
#
package Blut::Blocksplit::Output::TaggedFile;

use strict;
use warnings;

use parent 'Blut::Blocksplit::Output::FileBase';

our $VERSION = 0.1;


sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(shift);

    $self->{_tag} = shift;

    return bless $self, $class;
}


sub add {
    my ( $self, $arg ) = @_;

    return printf {$self->{_fh}} "%s:%s\n", $self->{_tag}, $arg;
}


1;
