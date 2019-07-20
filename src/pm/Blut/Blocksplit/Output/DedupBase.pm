# class Blut::Blocksplit::Output::DedupBase
#
# - ...
# -----------------------------------------------------------------------------
# + Blut::Blocksplit::Output::DedupBase(output)
#
package Blut::Blocksplit::Output::DedupBase;

use strict;
use warnings;

use parent 'Blut::Blocksplit::Output::Base';

our $VERSION = 0.1;


sub new {
    my $class = shift;
    my $self  = $class->SUPER::new();

    $self->{_out} = shift;

    return bless $self, $class;
}

sub check_new {
    die "method not implemented: check_new()\n";
}


sub is_null {
    my $self = shift;

    return $self->{_out}->is_null();
}


sub add {
    my ( $self, $arg ) = @_;

    if ( $self->check_new ( $arg ) ) {
        return $self->{_out}->add ( $arg );
    } else {
        return 1;
    }
}


1;
