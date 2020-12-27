/* ipset restore file generator
 *
 * Basic usage:
 *   COMMAND_PRODUCING_NETWORK_LISTS | ipset-gen table > ipset/table
 */

/* Compile w/: -std=C99 -D_POSIX_C_SOURCE=200809L */

#include "main.h"

struct main_options {
    const char* prog_name;

    int create_mode;
    int update_mode;

    /* str types: pass-through value only */
    const char* table_name;
    const char* timeout;
    const char* ip_family;
    const char* ipset_type;
    const char* hashsize;
    const char* maxelem;

    char*       fmt_add;
};

/** @returns: 1 if str is an integer > 0, non-zero otherwise */
static int check_str_is_positive_number ( const char* const str );

/** @returns: string format template, NULL on error */
static char* build_fmt_add ( const struct main_options* const opts );

/** prints the help message to the given file handle */
static void print_help ( const char* const prog_name, FILE* const fh );

void print_help ( const char* const prog_name, FILE* const fh ) {
    fprintf (
        fh,
        (
            "Usage:\n"
            "  %s [-t <timeout>] <table_name>\n"
            "\n"
            "  %s -c [-4|-6] [-T <set_type>] [-H <hashsize>] [-M <maxelem>]\n"
            "    [-t <timeout>] <table_name>\n"
            "\n"
            "Reads ipset networks (or other items) from stdin and writes them to stdout\n"
            "in a format suitable for restoring them using\n"
            "\n"
            "  ipset restore < FILE\n"
            "\n"
            "The restore command could be run on another machine\n"
            "with more constrained resources that benefits from a 'prepared' ipset.\n"
            "\n"
            "If used with the -c option, the output contains a 'create-ipset' line.\n"
            "\n"
            "Options:\n"
            "  -h               print this message and exit\n"
            "  -t <timeout>     entry timeout in seconds\n"
            "  -u               enable update mode (pass -exist for add/create)\n"
            "\n"
            "Create Options:\n"
            "  -c               include a create-ipset line\n"
            "  -4               set ipset family to IPv4 (default)\n"
            "  -6               set ipset family to IPv6\n"
            "  -T <set_type>    set ipset type (default: net)\n"
            "  -H <hashsize>    set ipset hashsize (default: omit, use ipset defaults)\n"
            "  -M <maxelem>     set ipset maxelem (default: omit, use ipset defaults)\n"
        ),
        prog_name, prog_name
    );
}


/* MAIN_GETOPT_STORE_POSINT ( attr_name, **optarg, **opts! )
 *   Stores optarg in opts.<attr_name> if it is a str containing a number > 0.
 *   On error, prints a message to stderr and returns from the main function -> exit
 */
#define MAIN_GETOPT_STORE_POSINT(_attr)  \
    do { \
        if ( STR_IS_EMPTY(optarg) ) { \
            (opts._attr) = NULL; \
        } else if ( check_str_is_positive_number(optarg) ) { \
            (opts._attr) = optarg; \
        } else { \
            fprintf ( stderr, "Bad %s value: %s\n", (#_attr), optarg ); \
            return EX_USAGE; \
        } \
    } while (0)

int main ( int argc, char** argv ) {
    static const char* const SHORT_OPTS = "46chH:M:t:T:u";

    int rc;
    int opt;

    /* init options */
    struct main_options opts = {
        .prog_name        = argv[0],  /* basename(), ... */

        .create_mode      = 0,
        .update_mode      = 0,

        .table_name       = NULL,
        .timeout          = NULL,

        .ip_family        = "inet",
        .ipset_type       = "hash:net",
        .hashsize         = NULL,
        .maxelem          = NULL,

        .fmt_add          = NULL
    };

    /* parse args */
    while ( (opt = getopt(argc, argv, SHORT_OPTS)) != -1 ) {
        switch ( opt ) {
            case 'h':
                print_help ( opts.prog_name, stdout );
                return EXIT_SUCCESS;

            case '4':
                opts.ip_family = "inet";
                break;

            case '6':
                opts.ip_family = "inet6";
                break;

            case 'c':
                opts.create_mode = 1;
                break;

            case 'H':
                MAIN_GETOPT_STORE_POSINT(hashsize);
                break;

            case 'M':
                MAIN_GETOPT_STORE_POSINT(maxelem);
                break;

            case 't':
                MAIN_GETOPT_STORE_POSINT(timeout);
                break;

            case 'T':
                if ( STR_IS_EMPTY(optarg) ) {
                    fprintf ( stderr, "Bad ipset type: <empty>\n" );
                    return EX_USAGE;

                } else {
                    opts.ipset_type = optarg;
                }

                break;

            case 'u':
                opts.update_mode = 1;
                break;

            default:
                fprintf ( stderr, "Usage error\n" );
                return EX_USAGE;
        }
    }

    if ( optind >= argc ) {
        fprintf ( stderr, "Missing <table> name argument.\n" );
        return EX_USAGE;
    }

    argv += optind;
    argc -= optind;

    /* positional argument: table name */
	opts.table_name = argv[0];
    if ( STR_IS_EMPTY(opts.table_name) ) {
        fprintf ( stderr, "Empty <table> name argument.\n" );
        return EX_USAGE;
    }

    /* error on leftover positional arguments */
    if ( argc > 1 ) {
        fprintf ( stderr, "Too many positional arguments!\n" );
        return EX_USAGE;
    }

    /* init "add ..." format string */
    opts.fmt_add = build_fmt_add ( &opts );
    if ( opts.fmt_add == NULL ) { return EX_SOFTWARE; }

    /* output "create ..." line? */
    if ( opts.create_mode ) {
        fprintf (
            stdout,
            "create%s %s %s%s%s%s%s%s%s%s%s\n",
            (opts.update_mode ?  " -exist" : ""),
            opts.table_name,
            opts.ipset_type,
            (STR_IS_EMPTY(opts.ip_family) ? "" : " family "),
            (STR_IS_EMPTY(opts.ip_family) ? "" : opts.ip_family),
            (STR_IS_EMPTY(opts.timeout)   ? "" : " timeout "),
            (STR_IS_EMPTY(opts.timeout)   ? "" : opts.timeout),
            (STR_IS_EMPTY(opts.hashsize)  ? "" : " hashsize "),
            (STR_IS_EMPTY(opts.hashsize)  ? "" : opts.hashsize),
            (STR_IS_EMPTY(opts.maxelem)   ? "" : " maxelem "),
            (STR_IS_EMPTY(opts.maxelem)   ? "" : opts.maxelem)
        );
    }

    /* stdin loop - write "add ..." lines */
    rc = process_file ( &opts, stdin );

    /* cleanup */
    /* close file if != stdin, ... */
    free(opts.fmt_add); opts.fmt_add = NULL;

    /* exit */
    if ( rc == 0 ) {
        return EXIT_SUCCESS;
    } else {
        return EXIT_FAILURE;
    }
}

#undef MAIN_GETOPT_STORE_POSINT


char* build_fmt_add ( const struct main_options* const opts ) {
    size_t fmt_add_size;
    int    sret;
    char*  buf;

    /* NOTE: ignoring timeout in create_mode */
    int want_timeout;

    want_timeout = ( (opts->timeout == NULL) || (opts->create_mode) ) ? 0 : 1;

    /* "add" [" -exist"] " " TABLE " " *ARG [" timeout " TIMEOUT] "\n" '\0' */
    fmt_add_size = (
        3       /* "add" */
        + (opts->update_mode ? 7 : 0)  /* " -exist" */
        + 1     /* " " */
        + strlen(opts->table_name)
        + 3     /* " %s" */
        + ( want_timeout ? (9 + strlen(opts->timeout)) : 0 )
        + 1     /* "\n" */
        + 1     /* '\0' */
    );

    buf = (char*) malloc ( fmt_add_size );
    if ( buf == NULL ) { return NULL; }

    sret = snprintf (
        buf, fmt_add_size,
        "add%s %s %%s%s%s\n",
        (opts->update_mode ?  " -exist" : ""),
        opts->table_name,
        (want_timeout ? " timeout " : ""),
        (want_timeout ? opts->timeout : "")
    );

    /* a return value of size or more ... output was truncated */
    if ( (sret < 0) || (((size_t) sret) >= fmt_add_size) ) {
        free(buf); buf = NULL;
        return NULL;
    }

    return buf;
}

int process_line (
    const struct main_options* const opts,
    const char* const line,
    __attribute__((unused)) const size_t slen
) {
    fprintf ( stdout, opts->fmt_add, line );
    return 0;
}


int check_str_is_positive_number ( const char* const str ) {
    unsigned status;
    const char* s;

    status = 0;  /* no digit 1..9 seen */

    s = str;
    do {
        switch (*s) {
            case '\0':
                return status;

            case '0':
                /* ok, but do not modifiy status */
                break;

            case '1':
            case '2':
            case '3':
            case '4':
            case '5':
            case '6':
            case '7':
            case '8':
            case '9':
                status = 1;
                break;

            default:
                /* error - bad char */
                return 0;
        }

        s++;
    } while (1);
}


#include "main.c"
