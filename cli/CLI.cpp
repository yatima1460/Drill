/**
 *  Very basic implementation of a Drill CLI version
 */
#include "engine.h"




using namespace Drill;

#include <signal.h>
#include <stdlib.h>
#include <stdio.h>

void my_handler(sig_atomic_t s)
{
    std::cout << "Stopping crawling..." << std::endl;
    exit(0); 
}


auto console = spdlog::stdout_color_mt("CLI");

void resultsCallback(FileInfo result)
{
    console->info("{0}", result.path);
}
   
int main(int argc, char const *argv[])
{
    signal (SIGINT, my_handler);

    if (argc < 2)
    {
        console->error("Usage: drill <searchValue>");
        return 1;
    }

    std::string searchValue = argv[1];

    console->set_pattern("%v");
    
    console->info("Drill CLI started");
    Drill::engine::search(searchValue, resultsCallback);

    return EXIT_SUCCESS;
}
