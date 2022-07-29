#include <iostream>
#include <string>
#include <thread>
#include <vector>

#include <algorithm>
#include "engine.h"
#include "os.h"
#include "path_string.h"

/**
 * @brief Search for a string in a directory and its subdirectories, this function returns only after
 * all threads are done
 * @param searchValue The value to search for.
 * @param results_callback The callback function to call for each result.
 */
std::vector<struct drill_crawler_config*> drill_search_async(const char *searchValue,
                                              void (*resultsCallback)(struct drill_result results))
{

    std::vector<struct drill_crawler_config*> crawlers;

    // auto console = spdlog::stdout_color_mt("Drill");

// #ifndef NDEBUG
//     console->set_level(spdlog::level::debug);
//     console->debug("Debug mode enabled");
// #else
//     console->set_level(spdlog::level::err);
// #endif

    // get drives
    std::vector<drill_path_string> mountpoints = drill_os_get_mountpoints();

    mountpoints.clear();
    // mountpoints.push_back(std::string("/"));
    // mountpoints = std::vector<std::string>{ "/" };

    // remove duplicates for drives list
    if (mountpoints.size() == 0)
    {
        //spdlog::error("No mountpoints found, falling back to root");
        mountpoints.push_back(drill_path_string_new("/"));
    }
    // else
    // {
    //     const size_t oldSize = mountpoints.size();
    //     std::sort(mountpoints.begin(), mountpoints.end());
    //     mountpoints.erase(std::unique(mountpoints.begin(), mountpoints.end()), mountpoints.end());

    //     // if (oldSize != mountpoints.size())
    //     //     console->warn("Found {0} duplicate entries in mountpoints, removed",
    //     //                   oldSize - mountpoints.size());
    // }

#ifndef NDEBUG
    for (const auto &mountpoint : mountpoints)
    {
        // console->debug("Found mountpoint `{0}`", mountpoint);
    }
#endif

    // for each drive spawn crawler
    for (const auto &mountpoint : mountpoints)
    {
        // FIXME: add other mou
        // FIXME: add other mountpoints in blocklist of this crawler
        struct drill_crawler_config* dcc = new drill_crawler_config();
        dcc->thread = nullptr;
        dcc->root = mountpoint;
        dcc->search_value = std::string(searchValue);
        dcc->results_callback = resultsCallback;
        dcc->stop = false;

        std::thread *thread_object = new std::thread(&drill_crawler_scan, dcc);
        dcc->thread = thread_object;

        // console->info("Spawned crawler for mountpoint `{0}`", mountpoint);
        crawlers.push_back(dcc);
    }

    return crawlers;
}

void drill_search_wait(std::vector<struct drill_crawler_config*> crawlers)
{
    for (size_t i = 0; i < crawlers.size(); i++)
    {
        crawlers[i]->thread->join();
    }
}


void drill_search_destroy_crawlers(std::vector<struct drill_crawler_config*> crawlers)
{
    for (size_t i = 0; i < crawlers.size(); i++)
    {
        delete crawlers[i];
        crawlers[i] = nullptr;
    }
}

void drill_search_stop_sync(std::vector<struct drill_crawler_config*> crawlers)
{
    drill_search_stop_async(crawlers);
    drill_search_wait(crawlers);
}

void drill_search_stop_async(std::vector<struct drill_crawler_config*> crawlers)
{
    for (size_t i = 0; i < crawlers.size(); i++)
    {
        crawlers[i]->results_callback = drill_crawler_stop_callback;
        crawlers[i]->stop = true;
    }
}
