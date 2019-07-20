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
my $short_usage = qq{${prog_name} {-c <N>|-h|-o <FILE>|-U <ZTYPE>} [<FILE>...]};
my $usage       = <<"EOF";
${NAME} (${VERSION}) - ${DESC}

Usage:
  ${short_usage}

Options:
  -C, --autocollapse <N>    reduce input domain names to depth <N>
  -h, --help                print this help message and exit
  -o, --outfile <FILE>      write output to <FILE> instead of stdout
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

    if (
        ! GetOptions (
            'C|autocollapse=i'  => \$autocol_depth,
            'h|help'            => \$want_help,
            'o|outfile=s'       => \$outfile,
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

    if ( scalar @ARGV ) {
        foreach (@ARGV) {
            open my $infh, '<', $_ or die "Failed to open input file: $!\n";
            $tree->read_fh ( $infh );
            close $infh or warn "Failed to close input file: $!\n";
        }

    } else {
        Blut::FileIO::read_fh_feed_object ( $tree, *STDIN );
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
        my $outfh;

        open $outfh, '>', $outfile or die "Failed to open outfile: $!\n";
        $ret = Blut::FileIO::write_to_fh ( $outfh, \@domains, $out_formatter );
        close $outfh or warn "Failed to close outfile: $!\n";

    } else {
        #$ret = write_domains_to_fh ( *STDOUT, \@domains, $outformat, $outformat_arg );
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
        _zone_type => (shift or 'always_nxdomain')
    };

    return bless $self, $class;
}

sub fmt {
    my ( $self, $arg ) = @_;

    return sprintf 'local-zone: "%s." %s', $_, $self->{_zone_type};
}
