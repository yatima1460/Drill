/**
 *  Very basic implementation of a Drill CLI version
 */

#include <stdio.h>
#include <stdlib.h>

#include "engine.h"

// Show only bare results fullpaths without any time or spdlog formatting
// Note: POSIX enforces that stdio is locking
void results_callback(struct drill_result result) { printf("%s\n", result.path); }

int main(int argc, char const *argv[])
{
    if (argc < 2)
    {
        fprintf(stderr, "Usage: drill <search_value>\n");
        return EXIT_FAILURE;
    }

    std::string searchValue = argv[1];

    // Start drilling in a sync way
    drill_search_wait(drill_search_async(searchValue, results_callback));

    return EXIT_SUCCESS;
}
