#!/usr/bin/env perl
package MulticallDispatcher;

use strict;
use warnings;
use English qw( -no_match_vars );

use Cwd;
use File::Basename;
use File::Spec;

our $VERSION = 1.0;

# get file name of the script to be executed
my $prog_name = File::Basename::basename ( $PROGRAM_NAME );
$prog_name =~ s/[.]pl$//msx;
$prog_name .= '.pl';

# get prjroot dir
my $prog_path = Cwd::realpath ( $PROGRAM_NAME );

my ( $volume, $directories, $file ) = File::Spec->splitpath ( $prog_path );

my @dirs = File::Spec->splitdir ( $directories );
# strip extra item if $directories ends with a trailing slash
if ( (scalar @dirs) && ( (!$dirs[-1]) || ($dirs[-1] eq q{/} ) ) ) { pop @dirs; }
pop @dirs;

# determine perl modules include dir and script file path,
# both to be found in <prjroot>/src/
# - modules dir
my $pm_lib_dir = File::Spec->catpath (
    $volume, File::Spec->catdir ( @dirs, 'src', 'pm' )
);
if ( (defined $ENV{PERL5LIB}) && ($ENV{PERL5LIB}) ) {
    $ENV{PERL5LIB} = $pm_lib_dir . q{:} . $ENV{PERL5LIB};
} else {
    $ENV{PERL5LIB} = $pm_lib_dir;
}

# - script file
my $exec_file = File::Spec->catpath (
    $volume, File::Spec->catdir ( @dirs, 'src', 'bin' ), $prog_name
);

# exec actual script file
exec $exec_file, @ARGV;
