#include "Engine.hpp"
#include "System.hpp"
#include "RegexUtils.hpp"

#include <spdlog/spdlog.h>
#include <thread>


namespace Drill
{

    std::vector<FileInfo> Engine::getResults()
    {
        
        std::vector<FileInfo> results;
        for (size_t i = 0; i < crawlersObjects.size(); i++)
        {

            const auto vector2 = crawlersObjects[i]->getResults();
            results.insert( results.end(), vector2.begin(), vector2.end() );


        }
        return results;
    }


Engine::~Engine()
{
    for (const Crawler* c : crawlersObjects)
    {
        delete c;
    }
    for (const std::thread* c : crawlers)
    {
        delete c;
    }
    //spdlog::drop_all();
}

bool Engine::isCrawling()
{
    bool atLeastOneRunning = false;
    for (size_t i = 0; i < crawlers.size(); i++)
    {
        if (crawlersObjects[i]->isRunning())
        {
            atLeastOneRunning = true;
            break;
        }
    }

    return atLeastOneRunning;
}


Engine::Engine(std::string searchValue) : searchValue(searchValue)
{

    // #ifndef NDEBUG
    spdlog::set_level(spdlog::level::debug);

    
    // #else
    //     spdlog::set_level(spdlog::level::warn);
    // #endif

    spdlog::info("Welcome to Drill!");
    if (searchValue.length() == 0)
        spdlog::critical("search string is empty");
    configs = loadConfigs();
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


    // std::vector<std::regex> mountpointsRegex;
    // for (const auto mountpoint : mountpoints)
    // {
    //     mountpointsRegex.push_back(std::regex(mountpoint));
    // }

    // mountpointsRegex[0].

    for (const auto mountpoint : mountpoints)
    {
        spdlog::debug("Found mountpoint `{0}`", mountpoint);

        // if in blocklists continue
        if (isInRegexList(configs.blocklistsRegex, mountpoint))
        {
            spdlog::debug("Mountpoint `{0}` in blocklist, skipping...", mountpoint);
            continue;
        }
        else
        {
            spdlog::info("Mountpoint `{0}` not in blocklist...", mountpoint);
            // Create thread object

            auto crawlerObject = new Crawler(mountpoint, configs, mountpoints);
            crawlersObjects.push_back(crawlerObject);
            std::thread *thread_object = new std::thread(&Crawler::run, crawlerObject);

            crawlers.push_back(thread_object);
        }
        

        
        // create thread
    }




    
        
}

void Engine::waitDrilling()
{
    for (auto *crawler : crawlers)
    {
        crawler->join();
        spdlog::info("Crawler joined", crawler->native_handle());
    }
}

} // namespace Drill
