#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

#include "core/context.c"



int main(int argc, char *argv[])
{

    struct drill_context dc = start_crawling();

    drill_wait_for_crawlers(dc);


    return 0;
    // bool isCaseInsensitive = false;
    // int opt;
    // enum { CHARACTER_MODE, WORD_MODE, LINE_MODE } mode = CHARACTER_MODE;

    // while ((opt = getopt(argc, argv, "ilw")) != -1) 
    // {
    //     switch (opt) {
    //     case 'i': isCaseInsensitive = true; break;
    //     case 'l': mode = LINE_MODE; break;
    //     case 'w': mode = WORD_MODE; break;
    //     default:
    //         fprintf(stderr, "Usage: %s [-ilw] [file...]\n", argv[0]);
    //         exit(EXIT_FAILURE);
    //     }
    // }

    // Now optind (declared extern int by <unistd.h>) is the index of the first non-option argument.
    // If it is >= argc, there were no non-option arguments.

    // ...
}