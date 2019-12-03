#include "Engine.hpp"
#include "System.hpp"
#include "RegexUtils.hpp"

#include <spdlog/spdlog.h>
#include <thread>
#include "Crawler.hpp"

namespace Drill
{

Engine::Engine(std::string searchValue) : searchValue(searchValue)
{

    // #ifndef NDEBUG
    spdlog::set_level(spdlog::level::info);
    // #else
    //     spdlog::set_level(spdlog::level::warn);
    // #endif

    spdlog::info("Welcome to Drill!");
    if (searchValue.length() == 0)
        spdlog::critical("search string is empty");
    configs = Config::loadConfigs();
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
        spdlog::debug("Found mountpoint {0}", mountpoint);

        // if in blocklists continue
        if (isInRegexList(configs.blocklistsRegex, mountpoint))
        {
            spdlog::debug("Mountpoint {0} in blocklist, skipping...");
            continue;
        }
        else
        {
            spdlog::trace("Mountpoint {0} not in blocklist, skipping...");
        }
        

        // Create thread object
        std::thread *thread_object = new std::thread(&Crawler::run, Crawler(mountpoint));

        crawlers.push_back(thread_object);
        // create thread
    }

    for (auto *crawler : crawlers)
    {
        crawler->join();
        spdlog::info("Crawler joined", crawler->native_handle());
    }
        
}
} // namespace Drill
