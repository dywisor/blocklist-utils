#include "main.h"

int process_file ( const struct main_options* const opts, FILE* const fh ) {
    char*   buf;
    size_t  bufsize;
    ssize_t read_ret;

    buf     = NULL;
    bufsize = 0;

    while ( (read_ret = getline ( &buf, &bufsize, fh ) ) > -1 ) {
        char*  line = buf;
        size_t slen = (size_t) read_ret;

        /* lstrip */
        while ( (slen > 0) && (CHR_IS_WHITESPACE(*line)) ) {
            line++;
            slen--;
        }

        /* rstrip */
        while ( (slen > 0) && (CHR_IS_WHITESPACE(line[slen - 1])) ) {
            line[--slen] = '\0';
        }

        if ( (slen > 0) && (line[0] != '#') ) {
            if ( process_line ( opts, line, slen ) != 0 ) {
                free(line); line = NULL;
                return -1;
            }
        }
    }

    free(buf); buf = NULL;
    return 0;
}
