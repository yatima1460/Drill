#pragma once



#include <string>
#include <vector>
#include <thread>
#include "Config.hpp"
#include "Crawler.hpp"

namespace Drill
{
class Engine
{

    std::vector<std::thread*> crawlers;
    std::vector<Crawler*> crawlersObjects;

    DrillConfig configs;
    // string searchValue, CrawlerCallback resultCallback, void* userObject

  

public:

    const std::string SEARCH_STRING;

    Engine(std::string searchValue);

    void startDrilling();

    // void setSearchValue(string);

    // void

    std::vector<FileInfo> pickupAllResults();

    bool isCrawling();
    
    void waitDrilling();

    void stopDrillingSync();

    void stopDrillingAsync();

    ~Engine();
};
} // namespace Drill
