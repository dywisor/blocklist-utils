# package Blut::FileIO
#
# + read_fh_feed_object ( obj, fh )
#   | obj->feed_line ( line ) foreach line in fh
# + read_file_feed_object  ( obj, file )
# + read_files_feed_object ( obj, *files )
#
# + write_to_fh    ( fh,   lines : ArrayRef<str>, [formatter] )
# + write_to_file  ( file, lines : ArrayRef<str>, [formatter] )
#
package Blut::FileIO;

use strict;
use warnings;
use feature qw( say );

our $VERSION = 0.2;


sub read_fh_feed_object {
    my ( $obj, $fh ) = @_;

    while (<$fh>) {
        # str_strip()
        s/^\s+//mx;
        s/\s+$//mx;

        # skip empty and comment lines
        if ( /^[^#]/mx ) {
            $obj->feed_line ( $_ ) or return 0;
        }
    }

    return 1;
}


sub read_file_feed_object {
    my ( $obj, $file ) = @_;
    my $ret;

    open my $fh, '<', $file or die "Failed to open input file: $!\n";
    $ret = read_fh_feed_object ( $obj, $fh );
    close $fh or warn "Failed to close input file: $!\n";

    return $ret;
}


sub read_files_feed_object {
    my $obj = shift;

    foreach (@_) {
        read_file_feed_object ( $obj, $_ ) or return 0;
    }

    return 1;
}


sub write_to_fh {
    my ( $fh, $lines_ref, $formatter ) = @_;

    if ( defined $formatter ) {
        foreach ( @{$lines_ref} ) {
            say {$fh} $formatter->fmt ( $_ ) or return 0;
        }

    } else {
        foreach ( @{$lines_ref} ) {
            say {$fh} $_ or return 0;
        }
    }

    return 1;
}


sub write_to_file {
    my $file = shift;
    my $ret;

    open my $fh, '>', $file or die "Failed to open output file: $!\n";
    $ret = write_to_fh ( $fh, @_ );
    close $fh or warn "Failed to close output file: $!\n";

    return $ret;
}


1;
