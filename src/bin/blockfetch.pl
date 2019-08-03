#!/usr/bin/perl
# -*- coding: utf-8 -*-

package BlockfetchMain;

use strict;
use warnings;
use feature qw( say );

use Getopt::Long qw(:config posix_default bundling no_ignore_case );
use File::Basename;

our $VERSION = '0.1';
our $NAME    = 'blockfetch';

my $prog_name   = File::Basename::basename($0);
my $short_usage = "${prog_name} {-B <BL>|-C <CFG>|-c|-f|-h|-l|-O <O>|-s|-T <T>|-u}";
my $usage       = <<"EOF";
${NAME} ${VERSION}

  Downloads blocklists and prepares them for further processing.

  This script is meant to be called periodically.
  It expects a configuration file in Perl syntax where each blocklist
  definition is a hash of options and gets appended to the bl array.
  After reading the blocklist definitions,
  ${NAME} will operate on them depending on the script mode.

  In the 'update' mode (the default), it determines
  which blocklist files have expired and recreates only these.
  If a blocklist cannot be downloaded or prepared, ${NAME} prints
  a warning and falls back to using the result of a previous invocation.
  However, if no previous file exists, the script stops and exits non-zero.

  The 'force-recreate' mode recreates all blocklist files unconditionally.
  Use this mode with care as downloading too frequently
  from a blocklist server might get you banned.
  Combine this mode with the -s, --skip-dl option to reapply
  parse/xform rules from your configuration without redownloading files.

  The -B, --bl option may be used to restrict operation to certain blocklists.
  Unknown blocklists will be silently ignored.

  Two more mode exist for diagnostic purposes.

  The 'list' mode prints out a list of blocklist names as read from the
  configuration file, This mode is unaffected by the -B, --bl option.

  The 'check' mode checks the expiry of all blocklists and reports the
  status, expiry and name of each blocklist.

  The status may be one of the following:

    o expired:      blocklist is out of date (expired in the past)
    o new:          blocklist file does not exist yet
    o up-to-date    blocklist is up to date (expires in the future if at all)

  An expire greater than zero indicates
  that the blocklist file expired that many seconds ago.
  A value of zero means that the blocklist expired just now,
  possibly because it is to be updated on every script invocation.
  Likewise, a value of '-' means that the blocklist will never expire.
  A value less than zero indicates that the blocklist
  will expire in that many seconds (absolute value).

  The fields are separated by TAB characters, one line per blocklist.
  Pipe the output to "column -t" to get a nicely formatted table.

Usage:
  ${short_usage}

Options:
  -B, --bl <BL>             restrict action to blocklist with the given name,
                            may be specified more than once
  -C, --config <CFG>        configuration file (blocklist definitions)
  -c, --check               check and report which files need to be fetched
  -f, --force-recreate      fetch and recreated all blocklists,
                            ignoring expiry
  -h, --help                print this help message and exit
  -l, --list                list blocklist definitions
  -O <O>                    output directory (default: ./bl)
  -s, --skip-dl             skip downloading if a file already exists,
                            regardless of age (useful together with -f)
  -T <T>                    output directory for temporary files
                            (default: <O>/tmp)
  -u, --update              fetch and recreate outdated blocklists

Exit Codes:
    0                       success
  255                       error
EOF


# main ( **@ARGV )
sub main {
    my $blocklist_config;
    my $f_check_bl_restrict;

    # parse args
    my $bl_restrict_names = {};
    my $mode        = undef;
    my $config_file = undef;
    my $output_dir  = undef;
    my $workdir     = undef;
    my $want_help   = 0;
    my $want_skipdl = 0;

    if (
        ! GetOptions (
            'B|bl=s'            => sub { $bl_restrict_names->{$_[1]} = 1; },
            'C|config=s'        => \$config_file,
            'c|check'           => sub { $mode = 'check'; },
            'f|force-recreate'  => sub { $mode = 'force-recreate'; },
            'h|help'            => \$want_help,
            'l|list'            => sub { $mode = 'list'; },
            'O=s'               => \$output_dir,
            's|skip-dl'         => \$want_skipdl,
            'T=s'               => \$workdir,
            'u|update'          => sub { $mode = 'update'; },

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

    if ( scalar @ARGV ) {
        die "no positional arguments accepted.\n";
    }

    if ( scalar %{ $bl_restrict_names } ) {
        $f_check_bl_restrict = sub { return $bl_restrict_names->{(shift)}; };
    } else {
        $f_check_bl_restrict = sub { return 1; };
    }

    $blocklist_config = Blocklists->new ( ($output_dir or './bl'), $workdir );

    if ( $config_file ) {
        # eval ( config_file )
        $blocklist_config = BlockfetchConfigLoader::load (
            $blocklist_config, $config_file
        );
    } else {
        die "no config file specified.\n";
    }

    if ( not defined $mode ) { $mode = 'update'; }

    if ( $mode eq 'check' ) {
        $blocklist_config->get_expired();

        ## printf {*STDOUT} "#%s\t%s\t%s\n", 'status', 'exp', 'name';

        foreach my $bl ( sort { $a->{name} cmp $b->{name} } @{ $blocklist_config->{bl} } ) {
            if ( &$f_check_bl_restrict ( $bl->{name} ) ) {
                my $exp = $bl->{expiry_info};

                printf {*STDOUT} "%s\t%s\t%s\n",
                    $exp->{status}, (defined $exp->{expiry} ? $exp->{expiry} : '-') , $bl->{name};
            }
        }

    } elsif ( $mode eq 'list' ) {
        foreach my $bl ( sort { $a->{name} cmp $b->{name} } @{ $blocklist_config->{bl} } ) {
            printf {*STDOUT} "%s\n", $bl->{name};
        }

    } elsif ( ($mode eq 'update') or ($mode eq 'force-recreate') ) {
        my $bl_expired;
        my @to_fetch;
        my @to_process;
        my @to_update_timestamp;
        my $f_do_fetch;

        dodir ( $blocklist_config->{outdir} ) or die "Failed to create output directory: $!\n";
        dodir ( $blocklist_config->{workdir} ) or die "Failed to create work directory: $!\n";

        FetchFile::init() or die;

        # phase 1: check expiry
        # always check expiry, otherwise accessing expiry info will lead to errors
        $bl_expired = $blocklist_config->get_expired();

        if ( $mode eq 'force-recreate' ) {
            $bl_expired = $blocklist_config->{bl};
        }

        foreach my $bl ( @$bl_expired ) {
            if ( &$f_check_bl_restrict ( $bl->{name} ) ) {
                push @to_fetch, $bl;
            }
        }
        undef $bl_expired;

        # phase 2: fetch files to workdir
        if ( $want_skipdl ) {
            $f_do_fetch = sub { my $bl = shift; return $bl->fetch_if_missing(); };

        } else {
            $f_do_fetch = sub { my $bl = shift; return $bl->fetch(); };
        }

        foreach my $bl ( @to_fetch ) {
            my $fetch_ret;

            say {*STDOUT} "DL ", $bl->{name};

            $fetch_ret = &$f_do_fetch ( $bl );

            if ( $fetch_ret ) {
                push @to_process, $bl;

            } elsif ( $bl->failsafe() ) {
                warn 'Failed to fetch blocklist, using previous version: ' . $bl->{name} . "\n";

            } else {
                die 'Failed to fetch blocklist: ' . $bl->{name} . "\n";
            }
        }
        undef @to_fetch;

        # phase 3: parse fetched files
        foreach my $bl ( @to_process ) {
            say {*STDOUT} "CC ", $bl->{name};

            if ( $bl->prepare() ) {
                $bl->rotate() or die 'Failed to move new blocklist: ' . $bl->{name} . "\n";
                push @to_update_timestamp, $bl;

            } elsif ( $bl->failsafe() ) {
                warn 'Failed to process blocklist, using previous version: ' . $bl->{name} . "\n";

            } else {
                die 'Failed to process blocklist: ' . $bl->{name} . "\n";
            }
        }
        undef @to_process;

        # phase 4: update mtime of blocklist files
        if ( scalar @to_update_timestamp ) {
            my $timestamp = time;

            foreach my $bl ( @to_update_timestamp ) {
                if ( $bl->update_timestamp ( $timestamp ) ) {
                    ;
                } else {
                    warn 'Failed to update mtime for blocklist: ' . $bl->{name} . "\n";
                }
            }
        }
        undef @to_update_timestamp;

        return 0;

    } else {
        die "main mode not implemented: ${mode}\n";
    }
}

sub dodir {
    my $dirpath = shift;

    return ( mkdir $dirpath or $!{EEXIST} );
}


exit main();


package BlockfetchConfigLoader;

use strict;
use warnings;

sub load {
    my $bl_config = shift;
    my $config_file = shift;

    our @bl;
    require $config_file;

    foreach my $bl_def_data (@bl) {
        $bl_config->add_blocklist ( Blocklist->new ( $bl_def_data ) );
    }

    return $bl_config;
}


package Blocklists;

use strict;
use warnings;
use File::Spec;

sub new {
    my $class = shift;
    my $self  = {
        outdir => shift,
        bl_map => {},
        bl     => []
    };

    $self->{workdir} = shift;
    if ( not defined $self->{workdir} ) {
        $self->{workdir} = File::Spec->catdir ( $self->{outdir}, 'tmp' );
    }

    return bless $self, $class;
}

sub get_by_name {
    my ( $self, $bl_name ) = @_;

    return $self->{bl_map}->{$bl_name};
}

sub add_blocklist {
    my ( $self, $bl_def ) = @_;

    if ( $bl_def->{enabled} ) {
        if ( not $bl_def->check_config() ) {
            die 'invalid blocklist def data: ' . ($bl_def->{name} ? $bl_def->{name} : '<unkown>') . "\n";
        }

        my $key = $bl_def->{name};

        if ( defined $self->{bl_map}->{$key} ) {
            die 'redefinition of blocklist: ' . $bl_def->{name} . "\n";

        } else {
            $bl_def->set_outfile (
                File::Spec->catfile ( $self->{outdir}, $bl_def->{name} )
            );

            $bl_def->set_tmpfile (
                File::Spec->catfile ( $self->{workdir}, $bl_def->{name} )
            );

            $self->{bl_map}->{$key} = $bl_def;
            push @{ $self->{bl} }, $bl_def;
        }

        return 1;

    } else {
        return 0;
    }
}


sub get_expired {
    my $self = shift;
    my $cmp_timestamp = shift;
    my @expired;

    if ( not defined $cmp_timestamp ) { $cmp_timestamp = time; }

    foreach my $bl_def (@{ $self->{bl} }) {
        if ( $bl_def->check_expiry ( $cmp_timestamp ) ) {
            push @expired, $bl_def;
        }
    }

    return \@expired;
}


package BlocklistExpiryInfo;

use strict;
use warnings;

sub new {
    my $class = shift;
    my $self  = {
        status  => shift,
        age     => shift,
        expiry  => shift
    };

    return bless $self, $class;
}

sub is_expired {
    my $self = shift;

    return ( (defined $self->{expiry}) && ($self->{expiry} >= 0) );
}


package Blocklist;

use strict;
use warnings;

use File::Copy;
use File::stat;


sub new {
    my $class = shift;
    my $args  = shift;
    my $self  = {
        enabled => (defined $args->{enabled}) ? $args->{enabled} : 1,
        name    => $args->{name},
        expire  => $args->{expire},
        url     => $args->{url},
        xform   => $args->{xform},
        parse   => $args->{parse},

        _stat_dirty => 1,
        _stat_info  => undef,

        _outfile    => undef,
        _tmpfile    => undef,
        _tmpfile_dl => undef,

        expiry_info => undef
    };

    return bless $self, $class;
}

sub get_expire {
    my $self = shift;
    my $exp = $self->{expire};

    return ( (not defined $exp) || ($exp < 0) ) ? -1 : $exp;
}


sub check_config {
    my $self = shift;

    return 1;
}


sub check_expiry {
    my ( $self, $cmp_timestamp ) = @_;
    my $st = $self->get_stat_info();

    if ( $st ) {
        my $age;
        my $cfg_expire;
        my $expiry;
        my $is_expired;

        $age = $cmp_timestamp - $st->mtime;

        $cfg_expire = $self->get_expire();

        if ( $cfg_expire < 0 ) {
            $expiry = undef;
            $is_expired = 0;

        } elsif ( $cfg_expire == 0 ) {
            $expiry = 0;    # regardless of age
            $is_expired = 1;

        } else {
            $expiry = $age - $cfg_expire;
            $is_expired = ($expiry < 0) ? 0 : 1;
        }

        $self->{expiry_info} = BlocklistExpiryInfo->new (
            ( $is_expired ? 'expired' : 'up-to-date' ),
            $age,
            $expiry
        );

        return $is_expired;

    } else {
        $self->{expiry_info} = BlocklistExpiryInfo->new ( 'new' );
        return 1;
    }
}


sub set_outfile {
    my ( $self, $outfile ) = @_;

    $self->{_stat_dirty} = 1;
    $self->{_outfile}    = $outfile;

    return 1;
}


sub set_tmpfile {
    my ( $self, $tmpfile ) = @_;

    $self->{_tmpfile}    = $tmpfile;
    $self->{_tmpfile_dl} = $tmpfile . '.dl';
}


sub get_stat_info {
    my $self = shift;

    if ( $self->{_stat_dirty} ) {
        my $st = stat ( $self->{_outfile} );

        if ( $st ) {
            $self->{_stat_dirty} = 0;
            $self->{_stat_info} = $st;

        } elsif ( $!{ENOENT} ) {
            $self->{_stat_dirty} = 0;
            $self->{_stat_info} = undef;

        } else {
            die "Failed to stat " . $self->{_outfile} . ": $!\n";
        }
    }

    return $self->{_stat_info};
}

sub fetch {
    my $self = shift;
    my $dst = $self->{_tmpfile_dl};
    my $dst_tmp = $dst . '.new';

    unlink $dst;    # retcode ignored

    FetchFile::get_file ( $dst_tmp, $self->{url} ) or return 0;

    return rename $dst_tmp, $dst;
}


sub fetch_if_missing {
    my $self = shift;

    if ( -f $self->{_tmpfile_dl} ) {
        return 1;

    } else {
        return $self->fetch();
    }
}


sub prepare {
    my $self = shift;

    my $ret;

    my $src = $self->{_tmpfile_dl};
    my $dst = $self->{_tmpfile};

    unlink $dst; # retcode ignored

    if ( ( defined $self->{parse} ) || ( defined $self->{xform} ) ) {
        my $infh;
        my $outfh;

        my $dst_tmp = $dst . '.new';

        $ret = 0;
        if ( open $outfh, '>', $dst_tmp ) {
            if ( open $infh, '<', $src ) {
                if ( defined $self->{parse} ) {
                    $ret = $self->_do_parse ( $infh, $outfh );
                } else {
                    $ret = $self->_do_xform ( $infh, $outfh );
                }

                close $infh;
            }

            close $outfh;
        }

        if ( $ret ) {
            $ret = rename $dst_tmp, $dst;
        }

    } else {
        my $st;

        $st = stat ( $src );

        if ( not $st ) {
            warn "Failed to stat " . $self->{_outfile} . ": $!\n";
            $ret = 0;

        } elsif ( $st->size < 1 ) {
            warn "Blocklist is empty: " . $self->{name} . "\n";
            $ret = 0;

        } else {
            $ret = ( link $src, $dst ) or ( File::Copy::copy ( $src, $dst ) );
        }
    }

    return $ret;
}


sub rotate {
    my $self = shift;
    my $newfile = $self->{_outfile} . '.new';

    unlink $newfile;

    ( link $self->{_tmpfile}, $newfile )
        or ( File::Copy::copy ( $self->{_tmpfile}, $newfile ) )
        or return 0;

    return rename $newfile, $self->{_outfile};
}


sub update_timestamp {
    my ( $self, $ts ) = @_;

    return utime $ts, $ts, $self->{_outfile};
}


sub failsafe {
    my $self = shift;

    return (defined $self->get_stat_info()) ? 1 : 0;
}


sub _do_xform {
    my ( $self, $infh, $outfh ) = @_;
    my $xform = $self->{xform};

    my $is_empty;
    my $in_str;

    $is_empty = 1;

    while (<$infh>) {
        # str_strip()
        s/^\s+//mx;
        s/\s+$//mx;

        $in_str = $_;

        # skip empty lines
        if ( $in_str ) {
            my $xform_ret = &$xform ( $in_str );
            my $xform_ret_type = ref($xform_ret);

            if ( $xform_ret ) {
                if ( not $xform_ret_type ) {
                    printf {$outfh} "%s\n", $xform_ret or return 0;
                    $is_empty = 0;

                } elsif ( $xform_ret_type eq 'ARRAY' ) {
                    foreach my $out_str ( @{ $xform_ret } ) {
                        printf {$outfh} "%s\n", $out_str or return 0;
                        $is_empty = 0;
                    }

                } else {
                    $xform_ret_type ||= "<none>";
                    die "Cannot handle xform result: " . $xform_ret . " (" . $xform_ret_type . ")\n";
                }
            }
        }
    }

    if ( $is_empty ) {
        warn "Blocklist is empty: " . $self->{name} . "\n";
        return 0;

    } else {
        return 1;
    }
}

sub _do_parse {
    my ( $self, $infh, $outfh ) = @_;
    my $parse = $self->{parse};

    my $input_data = do { local $/; <$infh>; };
    my $lines = &$parse ( $input_data );

    if ( defined $lines ) {
        foreach ( @{ $lines } ) {
            printf {$outfh} "%s\n", $_ or return 0;
        }

        return 1;

    } else {
        warn "Blocklist is empty: " . $self->{name} . "\n";
        return 0;
    }
}


package FetchFile;

use strict;
use warnings;

our $IMPL;
our $f_get_file;


sub init {
    if ( system ( 'ftp -MVo - -S dont file:///dev/null 1>/dev/null 2>/dev/null' ) == 0 ) {
        $IMPL       = 'openbsd-ftp';
        $f_get_file = \&openbsd_ftp_get_file;
        return 1;

    } elsif ( system ( 'curl --version 1>/dev/null 2>/dev/null' ) == 0 ) {
        $IMPL       = 'curl';
        $f_get_file = \&curl_get_file;

        return 1;

    } else {
        return 0;
    }
}

sub get_file { return &{ $f_get_file } ( @_ ); }

sub curl_get_cmdv {
    my $outfile = shift;
    my $url = shift;

    my @cmdv = ('curl', '--silent', '--fail', '--location');

    push @cmdv, '--max-time', '45';

    if ( defined $outfile ) {
        push @cmdv, '-o', $outfile;
    }

    push @cmdv, $url;

    return \@cmdv;
}


sub curl_get_file {
    my $cmdv = curl_get_cmdv ( @_ );

    return ( system ( @$cmdv ) == 0 );
}


sub openbsd_ftp_get_cmdv {
    my $outfile = shift;
    my $url = shift;

    my @cmdv = ('ftp', '-MnV');

    push @cmdv, '-w', '45';

    if ( defined $outfile ) {
        push @cmdv, '-o', $outfile;
    } else {
        push @cmdv, '-o', '-';
    }

    push @cmdv, $url;

    return \@cmdv;
}

sub openbsd_ftp_get_file {
    my $cmdv = openbsd_ftp_get_cmdv ( @_ );

    return ( system ( @$cmdv ) == 0 );
}


package Butil;

use strict;
use warnings;

sub get_field {
    my ( $re_sep, $field, $text ) = @_;

    if ( (defined $text) && ($text) ) {
        my @parts = split $re_sep, $text, ($field + 1);
        return $parts[$field - 1];

    } else {
        return $text;
    }
}


sub unquote {
    my $text = shift;

    if ( (defined $text) && ($text) ) {
        # len(text) > 1?
        my $a = (substr $text, 0, 1);
        my $b = (substr $text, -1, 1);

        if ( ( ($a eq q{'}) || ($a eq q{"}) ) && ($a eq $b) ) {
            return substr $text, 1, -1;

        } else {
            return $text;
        }

    } else {
        return $text;
    }
}

sub csv_field {
    return unquote ( get_field ( ',', shift, shift ) );
}


sub csv_tab_field {
    return unquote ( get_field ( '\t', shift, shift ) );
}
