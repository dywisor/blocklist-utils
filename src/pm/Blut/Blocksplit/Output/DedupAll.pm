# class Blut::Blocksplit::Output::DedupAll
#
# - ...
# -----------------------------------------------------------------------------
# + Blut::Blocksplit::Output::DedupAll(output)
#
package Blut::Blocksplit::Output::DedupAll;

use strict;
use warnings;

use parent 'Blut::Blocksplit::Output::DedupBase';

our $VERSION = 0.1;


sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);

    $self->{_seen} = undef;

    return bless $self, $class;
}


sub check_new {
    my ( $self, $arg ) = @_;

    if ( defined $self->{_seen}->{$arg} ) {
        return 0;

    } else {
        $self->{_seen}->{$arg} = 1;
        return 1;
    }
}


1;
