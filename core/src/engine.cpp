#include <iostream>
#include <string>
#include <thread>
#include <vector>

#include "spdlog/sinks/stdout_color_sinks.h"
#include "spdlog/spdlog.h"

#include "engine.h"
#include "os.h"

namespace Drill
{

    namespace engine
    {

        /**
         * @brief Search for a string in a directory and its subdirectories, this function returns only after
         * all threads are done
         * @param searchValue The value to search for.
         * @param results_callback The callback function to call for each result.
         */
        void search(std::string searchValue, void (*resultsCallback)(result::result results))
        {

            std::vector<std::thread *> crawlers;

            auto console = spdlog::stdout_color_mt("Drill");

#ifndef NDEBUG
            console->set_level(spdlog::level::debug);
            console->debug("Debug mode enabled");
#else
            console->set_level(spdlog::level::err);
#endif

            // get drives
            std::vector<std::string> mountpoints = system::get_mountpoints();

            mountpoints.clear();
            mountpoints.push_back(std::string("/"));
            // mountpoints = std::vector<std::string>{ "/" };

            // remove duplicates for drives list
            if (mountpoints.size() == 0)
            {
                spdlog::error("No mountpoints found, falling back to root");
                mountpoints.push_back("/");
            }
            else
            {
                const size_t oldSize = mountpoints.size();
                std::sort(mountpoints.begin(), mountpoints.end());
                mountpoints.erase(std::unique(mountpoints.begin(), mountpoints.end()), mountpoints.end());

                if (oldSize != mountpoints.size())
                    console->warn("Found {0} duplicate entries in mountpoints, removed",
                                  oldSize - mountpoints.size());
            }

#ifndef NDEBUG
            for (const auto mountpoint : mountpoints)
            {
                console->debug("Found mountpoint `{0}`", mountpoint);
            }
#endif

            // for each drive spawn crawler
            for (const auto mountpoint : mountpoints)
            {
                // FIXME: add other mountpoints in blocklist of this crawler
                std::thread *thread_object =
                    new std::thread(&Drill::crawler::scan, mountpoint, searchValue, resultsCallback, console);

                console->info("Spawned crawler for mountpoint `{0}`", mountpoint);
                crawlers.push_back(thread_object);
            }

            // wait for all crawlers to finish
            for (auto &thread : crawlers)
            {
                thread->join();
                delete thread;
            }
        }
    } // namespace engine

} // namespace Drill
