# abstract class Blut::OutfileMap
#
# - ...
# -----------------------------------------------------------------------------
# + Blut::OutfileMap()
# + close_files() : void
# + open_file ( file : str )
#
package Blut::OutfileMap;

use strict;
use warnings;

our $VERSION = 0.1;


sub new {
    my $class = shift;
    my $self  = {
        _fdmap => {}
    };

    return bless $self, $class;
}


sub close_files {
    my $self = shift;
    my $fdmap = $self->{_fdmap};

    foreach my $fh (values %$fdmap) {
        close $fh or warn "Failed to close output file: $!\n";
    }

    return 1;
}


sub open_file {
    my ( $self, $file ) = @_;
    my $key;

    if ( $file =~ /^\-?$/mx ) {
        return *STDOUT;
    }

    $key = $file;   # realpath, stat -> dev,inode or whatever

    if ( defined $self->{_fdmap}->{$key} ) {
        return $self->{_fdmap}->{$key};

    } else {
        open my $fh, '>', $file or die "Failed to open output file: $!\n";
        $self->{_fdmap}->{$key} = $fh;

        return $fh;
    }
}


1;
