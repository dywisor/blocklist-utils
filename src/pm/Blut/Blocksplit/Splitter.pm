# class Blut::Blocksplit::Splitter
#
# - ...
# -----------------------------------------------------------------------------
# + Blut::Blocksplit::Splitter ( out_ipv4, out_ipv6, out_domain, out_ignored )
# + process_file
#
package Blut::Blocksplit::Splitter;

use strict;
use warnings;
use 5.016;         # negative offset in substr

our $VERSION = 0.1;


sub new {
    my $class = shift;
    my $self  = {
        _out_ipv4    => shift,
        _out_ipv6    => shift,
        _out_domain  => shift,
        _out_ignored => shift
    };

    return bless $self, $class;
}

sub feed_line {
    my ( $self, $line ) = @_;

    # part of the input line being processed
    my $arg;

    # original input in case it was an url
    my $orig_arg;

    # whether input line was matched by any check,
    # but skip string concatenation if ignored output is disabled
    my $hit;

    # skip IPv4/IPv6 check depending on url
    my $skip_ipv4;
    my $skip_ipv6;

    # skip domain check depending on url or if input line is an IPv4/IPv6 address
    my $skip_domain;

    $arg = $line;
    $orig_arg = undef;
    $hit = 0;

    $skip_ipv4   = 0;
    $skip_ipv6   = 0;
    $skip_domain = 0;

    # Regular Expressions Cookbook, Second Edition
    #   8.10 Extracting the Host from a URL
    #   extract the interesting part from the url
    #   * <scheme>://[<user>@]<INTERESTING>[:<port>][/<remainder>|?...]
    #
    #   - allow repeated scheme https://http://...
    #   - allow single slash in scheme http:/
    #   - allow ":" in user/password
    #   - special IPv6 [] handling
    if ( $arg =~ /^(?:[a-z][a-z0-9+\-.]*:\/\/?)+(?:(?:[a-z0-9\-._~%!\$&'\(\)*+,;=:]+@)?)([^\/\?]+)(?:[\/|\?].*)?$/imx ) {
        $orig_arg = $arg;

        $arg = $1;
        # strip :<port>, if any
        $arg =~ s/\:[0-9]+$//mx;

        # IPv6 []
        if (
            ( (substr $arg, 0, 1) eq '[' )
            && ( (substr $arg, -1, 1) eq ']' )
        ) {
            $arg         = substr $arg, 1, -1;
            $skip_ipv4   = 1;
            $skip_domain = 1;

        } else {
            $skip_ipv6   = 1;
        }
    }

    #   8.16 Matching IPv4 Addresses,
    #    also allow netmask in CIDR notation  (?:\/(?:3[012]|[012]?[0-9]))?
    if (
        ( ! $skip_ipv4 )
        && ( $arg =~ /^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(?:\/(?:3[012]|[012]?[0-9]))?$/mx )
    ) {
        $hit = 1;
        $skip_domain = 1;

        $self->{_out_ipv4}->add ( $arg ) or return 0;
    }

    #   8.17 Matching IPv6 Addresses (standard or compressed notation),
    #    also allow prefixlen notation  (?:\/(?:12[0-8]|1[01][0-9]|0?[0-9]{1,2}))?
    if (
        ( ! $skip_ipv6 )
        && ( $arg =~ /^(?:(?:[A-F0-9]{1,4}:){7}[A-F0-9]{1,4}|(?=(?:[A-F0-9]{0,4}:){0,7}[A-F0-9]{0,4}(?:\/(?:12[0-8]|1[01][0-9]|0?[0-9]{1,2}))?$)(([0-9A-F]{1,4}:){1,7}|:)((:[0-9A-F]{1,4}){1,7}|:)|(?:[A-F0-9]{1,4}:){7}:|:(:[A-F0-9]{1,4}){7})(?:\/(?:12[0-8]|1[01][0-9]|0?[0-9]{1,2}))?$/imx )
    ) {
        $hit = 1;
        $skip_domain = 1;

        $self->{_out_ipv6}->add ( $arg ) or return 0;
    }

    #   8.15 Validating Domain Names
    #   ( $arg =~ /^(?:(?:xn--)?[a-z0-9]+(?:-[a-z0-9]+)*\.)+[a-z]{2,}$/imx )
    #
    #   - allow arbitrary amount of dash chars in IDN notation (xn--)
    #   - allow IDN notation in TLD
    #   - allow repeated dot chars, reduce to a single one
    #   - may end with "."
    #
    if (
        ( ! $skip_domain )
        && ( $arg =~ /^(?:(?:xn-+)?[a-z0-9]+(?:-[a-z0-9]+)*\.+)+(?:(?:xn-+)?[a-z0-9]+(?:-[a-z0-9]+)*)\.?$/imx )
    ) {
        my $domain = $arg;
        $domain =~ s/\.\.+/./gmx;
        $domain =~ s/\.+$//mx;

        if ( $domain ) {
            $hit = 1;

            $self->{_out_domain}->add ( $domain ) or return 0;
        }
    }

    if ( (! $hit) && (! $self->{_out_ignored}->is_null()) ) {
        if ( defined $orig_arg ) {
            $self->{_out_ignored}->add ( "${arg} (${orig_arg})" ) or return 0;
        } else {
            $self->{_out_ignored}->add ( $arg ) or return 0;
        }
    }

    return 1;
}


1;
