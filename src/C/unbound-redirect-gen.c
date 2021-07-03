/* unbound redirect zone config generator
 *
 * Basic usage:
 *   COMMAND_PRODUCING_DOMAINS | unbound-redirect-gen redir_addr > CONFIG_FILE
 */

/* Compile w/: -std=C99 -D_POSIX_C_SOURCE=200809L */
#include "main.h"

struct main_options {
    const char* prog_name;

    /* str types: pass-through value only */
    const char* redir_addr;
};


/** prints the help message to the given file handle */
static void print_help ( const char* const prog_name, FILE* const fh );

void print_help ( const char* const prog_name, FILE* const fh ) {
    fprintf ( fh, "Usage: %s <redir_addr>\n", prog_name );
}

int main ( int argc, char** argv ) {
    static const char* const SHORT_OPTS = "h";

    int rc;
    int opt;

    /* init options */
    struct main_options opts = {
        .prog_name  = argv[0],  /* basename(), ... */

        .redir_addr = NULL
    };

    /* parse args */
    while ( (opt = getopt(argc, argv, SHORT_OPTS)) != -1 ) {
        switch ( opt ) {
            case 'h':
                print_help ( opts.prog_name, stdout );
                return EXIT_SUCCESS;

            default:
                fprintf ( stderr, "Usage error\n" );
                return EX_USAGE;
        }
    }

    if ( optind >= argc ) {
        fprintf ( stderr, "Missing <redir_addr> argument.\n" );
        return EX_USAGE;
    }

    argv += optind;
    argc -= optind;

    /* positional argument: redir addr */
    opts.redir_addr = argv[0];
    if ( STR_IS_EMPTY(opts.redir_addr) ) {
        fprintf ( stderr, "Empty <redir_addr> argument.\n" );
        return EX_USAGE;
    }

    /* error on leftover positional arguments */
    if ( argc > 1 ) {
        fprintf ( stderr, "Too many positional arguments!\n" );
        return EX_USAGE;
    }

    /* stdin loop - write "add ..." lines */
    rc = process_file ( &opts, stdin );

    /* cleanup */
    /* close file if != stdin, ... */

    /* exit */
    if ( rc == 0 ) {
        return EXIT_SUCCESS;
    } else {
        return EXIT_FAILURE;
    }
}

int process_line (
    const struct main_options* const opts,
    const char* const line,
    __attribute__((unused)) const size_t slen
) {
    fprintf (
        stdout,
        "local-zone: \"%s.\" redirect\nlocal-data: \"%s. IN A %s\"\n",
        line,
        line,
        opts->redir_addr
    );
    return 0;
}


#include "main.c"
