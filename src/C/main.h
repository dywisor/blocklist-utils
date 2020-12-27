#ifndef _MAIN_H_
#define _MAIN_H_

#include <stdlib.h>
#include <stdio.h>
#include <sys/types.h>
#include <string.h>
#include <unistd.h>
#include <sysexits.h>

#define STR_IS_EMPTY(_s)        ( ((_s) == NULL) || (*(_s) == '\0') )
#define CHR_IS_WHITESPACE(_c)   ( ((_c) == ' ') || ((_c) == '\t') || ((_c) == '\r') || ((_c) == '\n') )
/* ^ incomplete CHR_IS_WHITESPACE */

struct main_options;  /* forward-declaration */

typedef int (*fn_process_one_str) ( const struct main_options* const opts, const char* const arg );

int process_file ( const struct main_options* const opts, FILE* const fh );
int process_line ( const struct main_options* const opts, const char* const line, const size_t slen );

#endif  /* _MAIN_H_ */
