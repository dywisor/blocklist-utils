/* squid ACL config generator
 *
 * Basic usage:
 *   COMMAND_PRODUCING_DOMAINS_XOR_IPS | squid-acl-gen [-4|-6|-D] ACL_NAME > CONFIG_FILE
 */

/* Compile w/: -std=C99 -D_POSIX_C_SOURCE=200809L */
#include "main.h"

struct main_options {
    const char* prog_name;

    /* str types: pass-through value only */
    const char* acl_name;

    /* acl type: dstdomain, dst, dstdomain -n, dst -n */
    const char* acl_type;
};


/** prints the help message to the given file handle */
static void print_help ( const char* const prog_name, FILE* const fh );

void print_help ( const char* const prog_name, FILE* const fh ) {
    fprintf (
        fh,
        (
            "Usage:\n"
            "  %s [-4|-6|-D] <acl_name>\n"
            "\n"
            "\n"
            "Creates a squid ACL configuration for the given input domains or networks.\n"
            "\n"
            "Options:\n"
            "  -h               print this message and exit\n"
            "  -4               input is IPv4 networks/addresses\n"
            "  -6               input is IPv6 networks/addresses\n"
            "  -D               input is domain names\n"
        ),
        prog_name
    );
}

int main ( int argc, char** argv ) {
    static const char* const SHORT_OPTS = "46Dh";

    int rc;
    int opt;

    /* init options */
    struct main_options opts = {
        .prog_name = argv[0],  /* basename(), ... */

        .acl_name  = NULL,

        .acl_type  = "dstdomain"
    };

    /* parse args */
    while ( (opt = getopt(argc, argv, SHORT_OPTS)) != -1 ) {
        switch ( opt ) {
            case 'h':
                print_help ( opts.prog_name, stdout );
                return EXIT_SUCCESS;

            case '4':
            case '6':
                opts.acl_type = "dst";
                break;

            case 'D':
                opts.acl_type = "dstdomain";
                break;

            default:
                fprintf ( stderr, "Usage error\n" );
                return EX_USAGE;
        }
    }

    if ( optind >= argc ) {
        fprintf ( stderr, "Missing <acl_name> argument.\n" );
        return EX_USAGE;
    }

    argv += optind;
    argc -= optind;

    /* positional argument: ACL name */
    opts.acl_name = argv[0];
    if ( STR_IS_EMPTY(opts.acl_name) ) {
        fprintf ( stderr, "Empty <acl_name> argument.\n" );
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
        (
            "acl %s %s %s\n"
            "acl %s %s .%s\n"
        ),
        opts->acl_name, opts->acl_type, line,
        opts->acl_name, opts->acl_type, line
    );
    return 0;
}


#include "main.c"
