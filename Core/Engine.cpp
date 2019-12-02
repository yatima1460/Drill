#include "Engine.hpp"
#include "System.hpp"
#include "Config.hpp"
#include <spdlog/spdlog.h>
#include <thread>
#include "Crawler.hpp"

namespace Drill
{

Engine::Engine(std::string searchValue) : searchValue(searchValue)
{
#ifndef NDEBUG
    spdlog::set_level(spdlog::level::trace);
#else
    spdlog::set_level(spdlog::level::warn);
#endif

    spdlog::info("Welcome to Drill!");
    if (searchValue.length() == 0)
        spdlog::critical("search string is empty");
    Config::loadConfigs();
}

void Engine::startDrilling()
{

    auto mountpoints = System::getMountpoints();

    if (mountpoints.size() == 0)
    {
        spdlog::warn("No mountpoints found, falling back to root");
        mountpoints.push_back("/");
    }
    else
    {

        const size_t oldSize = mountpoints.size();
        std::sort(mountpoints.begin(), mountpoints.end());
        mountpoints.erase(std::unique(mountpoints.begin(), mountpoints.end()), mountpoints.end());

        if (oldSize != mountpoints.size())
            spdlog::warn("Found {0} duplicate entries in mountpoints, removed", oldSize - mountpoints.size());
    }

    for (const auto mountpoint : mountpoints)
    {
        spdlog::info("Found mountpoint {0}", mountpoint);

        // if in blocklists continue
        if (false)
        {
            spdlog::info("Mountpoint {0} in blocklist, skipping...");
            continue;
        }

        // Create thread object
        std::thread *thread_object = new std::thread(&Crawler::run, Crawler(mountpoint));

        crawlers.push_back(thread_object);
        // create thread
    }

    for (auto *crawler : crawlers)
        crawler->join();
}
} // namespace Drill
