# package Blut::FileIO
#
# + read_fh_feed_object ( obj, fh )
#   | obj->feed_line ( line ) foreach line in fh
#
# + write_to_fh ( fh, lines : ArrayRef<str>, [formatter] )
#
package Blut::FileIO;

use strict;
use warnings;
use feature qw( say );

our $VERSION = 0.1;


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


1;
