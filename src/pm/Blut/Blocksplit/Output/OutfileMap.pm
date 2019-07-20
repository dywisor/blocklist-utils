# abstract class Blut::Blocksplit::Output::OutfileMap
#
# - ...
# -----------------------------------------------------------------------------
# + Blut::Blocksplit::Output::OutfileMap()
#
package Blut::Blocksplit::Output::OutfileMap;

use strict;
use warnings;

use Blut::Blocksplit::Output::Null;
use Blut::Blocksplit::Output::File;
use Blut::Blocksplit::Output::TaggedFile;


use parent 'Blut::OutfileMap';

our $VERSION = 0.1;


sub new {
    my $class = shift;
    my $self  = $class->SUPER::new();

    return bless $self, $class;
}


sub get_file {
    my ( $self, $individual_file_arg, $combined_tag, $combined_file_arg ) = @_;

    if ( defined $individual_file_arg ) {
        return Blut::Blocksplit::Output::File->new (
            $self->open_file ( $individual_file_arg )
        );

    } elsif ( (defined $combined_tag) && (defined $combined_file_arg) ) {
        return Blut::Blocksplit::Output::TaggedFile->new (
            $self->open_file ( $combined_file_arg ),
            $combined_tag
        );

    } else {
        return Blut::Blocksplit::Output::Null->new();
    }
}


1;
