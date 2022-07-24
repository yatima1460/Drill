/**
 *  Very basic implementation of a Drill CLI version
 */

#include <stdio.h>
#include <stdlib.h>

#include "engine.h"

auto console = spdlog::stdout_color_mt("CLI");

void results_callback(Drill::result::result result) { console->info("{0}", result.path); }

int main(int argc, char const *argv[])
{
    if (argc < 2)
    {
        console->error("Usage: drill <search_value>");
        return EXIT_FAILURE;
    }

    std::string searchValue = argv[1];

    // show only bare results fullpaths without any time or spdlog formatting
    console->set_pattern("%v");

    // start drilling
    Drill::engine::search(searchValue, results_callback);

    return EXIT_SUCCESS;
}
