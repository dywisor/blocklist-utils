# class DnsTree
#
# - _acd : int
# - _root : Blut::DnsDedup::Node
# -----------------------------------------------------------------------------
# + DnsTree ( autocol_depth=undef : int )
# + collect() : ArrayRef<str>
# + insert ( domain_name : str ) : void
# + read_fh ( fh : int ) : void
#
package Blut::DnsDedup::Tree;

use strict;
use warnings;

use Blut::DnsDedup::Node;

our $VERSION = 0.1;


sub new {
    my $class = shift;
    my $self  = {
        # auto collapse depth, may be undef for no autocol
        _acd  => shift,
        _root => Blut::DnsDedup::Node->new ( '.' )
    };

    return bless $self, $class;
}


# collect ( self )
sub collect {
    my $self = shift;
    my @dst_arr = ();

    $self->{_root}->collect ( \@dst_arr );

    return \@dst_arr;
}


# insert ( self, domain_name )
sub insert {
    my ( $self, $domain_name ) = @_;

    # lowercase -> split on "." -> ignore empty parts
    my @key_path = grep { '/./' } ( split /[.]/mx, lc $domain_name );

    # auto-collapse if enabled
    if ( (defined $self->{_acd}) && ($self->{_acd} >= 0) ) {
        my $excess = (scalar @key_path) - $self->{_acd};

        if ( $excess > 0 ) {
            @key_path = @key_path [ $excess .. $#key_path ];
        }
    }

    # insert
    $self->{_root}->insert ( \@key_path );

    return 1;
}


# feed_line ( self, line ) -> insert(...)
sub feed_line {
    my $self = shift;
    return $self->insert ( @_ );
}


1;
