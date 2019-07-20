# class Blut::DnsDedup::Node
#
# - _name: str
# - _hot: bool
# - _nodes: HashRef<str, Blut::DnsDedup::Node>
# -----------------------------------------------------------------------------
# + Blut::DnsDedup::Node ( name=undef : str )
# + insert ( key_path : ArrayRef<str> ) : Blut::DnsDedup::Node
# + collect ( dst_arr : ArrayRef<str> ) : void
# # get_child_node_name ( subdomain : str ) : str
# # get_child_node ( subdomain : str ) : Blut::DnsDedup::Node
#
package Blut::DnsDedup::Node;

use strict;
use warnings;

our $VERSION = 0.1;

our $MODE_TRANSIENT       = 0;
our $MODE_HOT             = 1;
our $MODE_TRANSIENT_PURGE = 2;
our $MODE_PURGE           = 3;


sub new {
    my $class = shift;
    my $self  = {
        _name  => shift,  # may be undef
        _hot   => $MODE_TRANSIENT,
        _nodes => {}
    };

    return bless $self, $class;
}


# get_child_node_name ( self, subdomain )
sub get_child_node_name {
    my ( $self, $subdomain ) = @_;

    my $name = $self->{_name};

    if ( ($name) && ($name ne '.') ) {
        return join '.', ( $subdomain, $name );
    } else {
        return $subdomain;
    }
}


# get_child_node ( subdomain )
sub get_child_node {
    my ( $self, $subdomain ) = @_;

    my $nodes = $self->{_nodes};
    my $node;

    if ( exists $nodes->{$subdomain} ) {
        $node = $nodes->{$subdomain};

    } else {
        $node = Blut::DnsDedup::Node->new ( $self->get_child_node_name ( $subdomain ) );
        $nodes->{$subdomain} = $node;
    }

    return $node;
}


# insert ( self, key_path )
sub insert {
    # mode transition table for insert operation:
    # TRANSIENT       -> { TRANSIENT, HOT }
    # TRANSIENT_PURGE -> { TRANSIENT_PURGE }
    # HOT             -> { HOT }
    # PURGE           -> { PURGE }
    #
    my ( $self, $key_path ) = @_;

    my $node_key = pop @{ $key_path };

    if ( ( $self->{_hot} == $MODE_HOT ) || ( $self->{_hot} == $MODE_PURGE ) ) {
        # leaf node, keep as-is
        return $self;

    } elsif ( not defined $node_key ) {
        # cannot transition from transient purge node
        if ( $self->{_hot} == $MODE_TRANSIENT ) {
            $self->{_hot} = $MODE_HOT;
        }
        return $self;

    } else {
        my $node = $self->get_child_node ( $node_key );
        return $node->insert ( $key_path );
    }
}


# insert_purge ( self, key_path )
sub insert_purge {
    # mode transition table for insert_purge operation:
    # TRANSIENT       -> { TRANSIENT_PURGE, PURGE }
    # TRANSIENT_PURGE -> { TRANSIENT_PURGE, PURGE }
    # HOT             -> { TRANSIENT_PURGE, PURGE }
    # PURGE           -> { PURGE }
    #
    my ( $self, $key_path ) = @_;

    my $node_key = pop @{ $key_path };

    if ( $self->{_hot} == $MODE_PURGE ) {
        # purge leaf node, keep as-is
        return $self;

    } elsif ( not defined $node_key ) {
        $self->{_hot} = $MODE_PURGE;
        return $self;

    } else {
        $self->{_hot} = $MODE_TRANSIENT_PURGE;
        my $node = $self->get_child_node ( $node_key );
        return $node->insert_purge ( $key_path );
    }
}


# collect ( self, dst_arr )
sub collect {
    my ( $self, $dst_arr ) = @_;

    if ( $self->{_hot} == $MODE_HOT ) {
        push @{ $dst_arr }, $self->{_name};

    } else {
        # sort by top-level domain, then second-level domain a.s.o.
        foreach my $key ( sort keys %{ $self->{_nodes} } ) {
            $self->{_nodes}->{$key}->collect ( $dst_arr );
        }
    }

    return 1;
}


1;
