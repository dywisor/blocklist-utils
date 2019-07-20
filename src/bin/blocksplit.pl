#!/usr/bin/perl
# -*- coding: utf-8 -*-

# FIXME: class inheritance
# - how to @ISA when parent / subclass are in the same file?
# - or create one file per class...
#

package BlocksplitMain;

use strict;
use warnings;
use feature qw( say );

use Getopt::Long qw(:config posix_default bundling no_ignore_case );
use File::Basename qw ( basename );

use Blut::FileIO;
use Blut::Blocksplit::Splitter;
use Blut::Blocksplit::Output::OutfileMap;
use Blut::Blocksplit::Output::DedupAll;
use Blut::Blocksplit::Output::DedupPrevious;

our $VERSION = '0.1';
our $NAME    = 'blocksplit';

my $prog_name   = basename($0);
my $short_usage = "${prog_name} {-4 <FILE>|-6 <FILE>|-D <FILE>|-h|-I <FILE>|-o <FILE>|-u} [<FILE>...]";
my $usage       = <<"EOF";
${NAME} ${VERSION}

  Reads domains and IP addresses and writes them
  to individual output files or a combined one.

  Each line in the input should match one of the following:
    o IPv4 address/network, optionally followed by a netmask in CIDR notation
    o IPv6 address/network in standard or compressed notation,
      optionally followed by its prefix length
    o domain name
    o URL with any of the above in its host part
      (IP addresses without netmask/prefixlen only)

  IPv6 addresses in mixed notation are not supported.

  Examples:
    o 198.51.100.5
    o 198.51.100.128/25
    o 2001:db8:3:4:5:6:7:8
    o 2001:db8:a::1
    o 2001:db8:b::/48
    o example.com
    o http://example.net:81/stuff
    o http://198.51.100.10?payload=1
    o https://[2001:db8::1]/

  For each line in the input files, leading and trailing whitespace is removed.
  Empty lines, possibly caused by this conversion, are silently ignored.
  Likewise, lines starting with a '#' are ignored, too.

  The input may be garbage and parser is not perfect, either.
  For these reasons, unmatched input, i.e. text being neither ignored nor
  parsed as address or domain, may be written to a separate file (-I option).

  When a combined output file is used (-o option),
  then output each line will start with a 4, 6 or D to indicate its type,
  followed by a colon char ':' and the actual data (i.e. address / domain).
  Combined output does not include unmatched input.

  Repeated output of the same IP address or domain gets suppressed,
  but only if it is equal to the most recent previous output item.
  The -u option may be used to get unique output items only.
  This will increase memory consumption dramatically
  since blocksplit needs to remember all previous items.
  In either case, simple string checks are used to determine uniqueness,
  anything more advanced needs to be carried out with other programs.
  For example, both sub.example.com and example.com would appear in the output,
  despite the former being overshadowed by the latter.

Usage:
  ${short_usage}

Options:
  -4 <FILE>                 write IPv4 addresses to <FILE>
  -6 <FILE>                 write IPv6 addresses to <FILE>
  -D <FILE>                 write domain names to <FILE>
  -h, --help                print this help message and exit
  -I <FILE>                 write ignored input to <FILE>
  -o <FILE>                 write output in tagged notation to <FILE>
                            unless overridden by -4/-6/-D
                            note that -o output does not include ignored input
  -u, --unique              drop duplicate output items
                            (increases memory consumption)

Positional Arguments:
  FILE...                   read input from files instead of stdin

Exit Codes:
    0                       success
  255                       error
EOF

our $EMPTY = q{};


# main ( **@ARGV )
sub main {
    my $outfiles_map;
    my $splitter;

    # parse args
    my $outfile_ipv4        = undef;
    my $outfile_ipv6        = undef;
    my $outfile_domains     = undef;
    my $outfile_ignored     = undef;
    my $outfile_combined    = undef;
    my $want_help           = 0;
    my $want_dedup          = 0;

    if (
        ! GetOptions (
            '4=s'       => \$outfile_ipv4,
            '6=s'       => \$outfile_ipv6,
            'D=s'       => \$outfile_domains,
            'h|help'    => \$want_help,
            'I=s'       => \$outfile_ignored,
            'o=s'       => \$outfile_combined,
            'u|unique'  => \$want_dedup
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

    #$outfiles_map = OutfilesMap->new($want_dedup);
    $outfiles_map = Blut::Blocksplit::Output::OutfileMap->new();

    # TODO/FIXME: ref to pkg->new?
    my $f_create_dedup = ($want_dedup) ? \&create_dedup_all : \&create_dedup_previous;

    $splitter = Blut::Blocksplit::Splitter->new (
        &$f_create_dedup (
            $outfiles_map->get_file ( $outfile_ipv4, '4', $outfile_combined )
        ),
        &$f_create_dedup (
            $outfiles_map->get_file ( $outfile_ipv6, '6', $outfile_combined )
        ),
        &$f_create_dedup (
            $outfiles_map->get_file ( $outfile_domains, 'D', $outfile_combined )
        ),
        $outfiles_map->get_file ( $outfile_ignored, undef, undef )
    );

    if ( scalar @ARGV ) {
        Blut::FileIO::read_files_feed_object ( $splitter, @ARGV ) or die "Failed to process input files\n";

    } else {
        Blut::FileIO::read_fh_feed_object ( $splitter, *STDIN ) or die "Failed to read input\n";
    }

    $outfiles_map->close_files();

    return 0;
}


sub create_dedup_all {
    return Blut::Blocksplit::Output::DedupAll->new ( @_ );
}


sub create_dedup_previous {
    return Blut::Blocksplit::Output::DedupPrevious->new ( @_ );
}


exit main();
