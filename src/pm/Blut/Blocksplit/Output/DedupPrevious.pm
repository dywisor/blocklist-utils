# class Blut::Blocksplit::Output::DedupPrevious
#
# - ...
# -----------------------------------------------------------------------------
# + Blut::Blocksplit::Output::DedupPrevious(output)
#
package Blut::Blocksplit::Output::DedupPrevious;

use strict;
use warnings;

use parent 'Blut::Blocksplit::Output::DedupBase';

our $VERSION = 0.1;


sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);

    $self->{_prev} = undef;

    return bless $self, $class;
}


sub check_new {
    my ( $self, $arg ) = @_;

    if ( (defined ${self}->{_prev}) && (${self}->{_prev} eq $arg) ) {
        return 0;

    } else {
        $self->{_prev} = $arg;
        return 1;
    }
}


1;
