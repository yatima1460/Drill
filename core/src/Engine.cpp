#include "engine.h"

#include "RegexUtils.hpp"

#include "spdlog/spdlog.h"
#include "spdlog/sinks/stdout_color_sinks.h"
#include <thread>
#include <iostream>
#include <vector>
#include <string>
#include "system.h"

namespace Drill
{

    namespace engine
    {

        void search(std::string searchValue, void (*resultsCallback)(FileInfo results))
        {

            std::vector<std::thread*> crawlers;
          
            auto console = spdlog::stdout_color_mt("Drill");

#ifndef NDEBUG
        console->set_level(spdlog::level::debug);
#else
        console->set_level(spdlog::level::err);
#endif

            // get drives
            
            std::vector<std::string> mountpoints = system::get_mountpoints();

            mountpoints.clear();
            mountpoints.push_back(std::string("/"));
            //mountpoints = std::vector<std::string>{ "/" };

            //remove duplicates for drives list
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

                // auto crawlerObject = new Crawler(mountpoint, configs, mountpoints);
                // crawlersObjects.push_back(crawlerObject);
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

    // std::vector<FileInfo> EngineObj::pickupAllResults()
    // {

    //     std::vector<FileInfo> results;
    //     for (size_t i = 0; i < crawlersObjects.size(); i++)
    //     {

    //         const auto vector2 = crawlersObjects[i]->pickupResults();
    //         results.insert(results.end(), vector2.begin(), vector2.end());
    //     }
    //     return results;
    // }

//     EngineObj::~EngineObj()
//     {
//         // TODO: stop drilling?
//         for (const Crawler *c : crawlersObjects)
//         {
//             delete c;
//         }
//         for (const std::thread *c : crawlers)
//         {
//             delete c;
//         }
//         // spdlog::drop_all();
//     }

//     bool EngineObj::isCrawling()
//     {
//         bool atLeastOneRunning = false;
//         for (size_t i = 0; i < crawlers.size(); i++)
//         {
//             if (crawlersObjects[i]->isRunning())
//             {
//                 atLeastOneRunning = true;
//                 break;
//             }
//         }

//         return atLeastOneRunning;
//     }

//     EngineObj::EngineObj(std::string searchValue) : SEARCH_STRING(searchValue)
//     {

// #ifndef NDEBUG
//         spdlog::set_level(spdlog::level::debug);
// #else
//         spdlog::set_level(spdlog::level::info);
// #endif

//         spdlog::info("Welcome to Drill!");
//         if (searchValue.length() == 0)
//             spdlog::critical("search string is empty");
//         configs = loadConfigs();
//     }

//     void EngineObj::startDrilling()
//     {

//         auto mountpoints = system::get_mountpoints();

//         if (mountpoints.size() == 0)
//         {
//             spdlog::warn("No mountpoints found, falling back to root");
//             mountpoints.push_back("/");
//         }
//         else
//         {
//             const size_t oldSize = mountpoints.size();
//             std::sort(mountpoints.begin(), mountpoints.end());
//             mountpoints.erase(std::unique(mountpoints.begin(), mountpoints.end()), mountpoints.end());

//             if (oldSize != mountpoints.size())
//                 spdlog::warn("Found {0} duplicate entries in mountpoints, removed",
//                              oldSize - mountpoints.size());
//         }

//         // std::vector<std::regex> mountpointsRegex;
//         // for (const auto mountpoint : mountpoints)
//         // {
//         //     mountpointsRegex.push_back(std::regex(mountpoint));
//         // }

//         // mountpointsRegex[0].

//         for (const auto mountpoint : mountpoints)
//         {
//             spdlog::debug("Found mountpoint `{0}`", mountpoint);

//             // if in blocklists continue
//             if (isInRegexList(configs.blocklistsRegex, mountpoint))
//             {
//                 spdlog::debug("Mountpoint `{0}` in blocklist, skipping...", mountpoint);
//                 continue;
//             }
//             else
//             {
//                 spdlog::info("Mountpoint `{0}` not in blocklist...", mountpoint);
//                 // Create thread object

//                 auto crawlerObject = new Crawler(mountpoint, configs, mountpoints);
//                 crawlersObjects.push_back(crawlerObject);
//                 std::thread *thread_object = new std::thread(&Crawler::run, crawlerObject);

//                 crawlers.push_back(thread_object);
//             }

//             // create thread
//         }
//     }

//     void EngineObj::waitDrilling()
//     {
//         for (auto *crawler : crawlers)
//         {
//             crawler->join();
//             spdlog::debug("Crawler joined", crawler->native_handle());
//         }
//     }

} // namespace Drill
