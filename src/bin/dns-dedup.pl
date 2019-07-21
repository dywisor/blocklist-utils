#!/usr/bin/env perl
#
package DnsDedupMain;

use strict;
use warnings;
use feature qw( say );

use Getopt::Long qw(:config posix_default bundling no_ignore_case );
use File::Basename;

use Blut::DnsDedup::Tree;
use Blut::FileIO;

our $VERSION = 0.2;
our $NAME    = q{dns-dedup};
our $DESC    = q{deduplicate domain name lists};

my $prog_name   = File::Basename::basename($0);
my $short_usage = qq{${prog_name} {-c <N>|-h|-o <FILE>|-p <FILE>|-U <ZTYPE>} [<FILE>...]};
my $usage       = <<"EOF";
${NAME} (${VERSION}) - ${DESC}

Usage:
  ${short_usage}

Options:
  -C, --autocollapse <N>    reduce input domain names to depth <N>
  -h, --help                print this help message and exit
  -o, --outfile <FILE>      write output to <FILE> instead of stdout
  -p, --purge <FILE>        read excludes from <FILE>
                            may be specified more than once
  -U, --unbound [<ZTYPE>]   write output in unbound.conf(5) local-zone format
                            ZTYPE may be used to set the zone type,
                            it defaults to \"always_nxdomain\".
                            (convenience helper)

Positional Arguments:
  FILE...                   read domain names from files instead of stdin

Exit Codes:
    0                       success
   64                       usage error
  255                       error
EOF


# main ( **@ARGV )
sub main {
    my $ret;

    # parse args
    my $autocol_depth   = undef;
    my $want_help       = 0;
    my $outfile         = undef;
    my $outformat       = undef;
    my $outformat_arg   = undef;
    my @purge_infiles;

    if (
        ! GetOptions (
            'C|autocollapse=i'  => \$autocol_depth,
            'h|help'            => \$want_help,
            'o|outfile=s'       => \$outfile,
            'p|purge=s'         => sub {
                push @purge_infiles, $_[1];
            },
            'U|unbound:s'       => sub {
                $outformat = 'unbound';
                $outformat_arg = $_[1];
            }
        )
    ) {
        say {*STDERR} 'Usage: ', $short_usage or die "!$\n";
        return 1;  # FIXME EX_USAGE
    }

    # help => exit
    if ( $want_help ) {
        # newline at end supplied by $usage
        print $usage or die "!$\n";
        return 0;
    }

    # create DNS tree, read input files
    my $tree = Blut::DnsDedup::Tree->new ( $autocol_depth );

    if ( scalar @purge_infiles ) {
        Blut::FileIO::read_files_feed_object ( $tree, \@purge_infiles, 2 ) or die;
    }

    if ( scalar @ARGV ) {
        Blut::FileIO::read_files_feed_object ( $tree, \@ARGV, 1 ) or die;
    } else {
        Blut::FileIO::read_fh_feed_object ( $tree, *STDIN, 1 ) or die;
    }

    my @domains = @{ $tree->collect() };

    my $out_formatter = undef;

    if ( $outformat ) {
        if ( $outformat eq 'unbound' ) {
            $out_formatter = UnboundFormatter->new ( $outformat_arg );
        } else {
            die "outformat not implemented: ${outformat}\n";
        }
    }

    # write output file
    if ( defined $outfile ) {
        $ret = Blut::FileIO::write_to_file ( $outfile, \@domains, $out_formatter );

    } else {
        $ret = Blut::FileIO::write_to_fh ( *STDOUT, \@domains, $out_formatter );
    }

    die "Failed to write domains!\n" unless ( $ret );

    return 0;
}


exit main();


package UnboundFormatter;

use strict;
use warnings;

sub new {
    my $class = shift;
    my $self  = {
        _zone_type => shift
    };

    if ( not defined $self->{_zone_type} ) {
        $self->{_zone_type} = 'always_nxdomain';
    }

    return bless $self, $class;
}

sub fmt {
    my ( $self, $arg ) = @_;

    return sprintf 'local-zone: "%s." %s', $_, $self->{_zone_type};
}
