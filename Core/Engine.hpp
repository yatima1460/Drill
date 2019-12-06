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

    std::string searchValue;

public:
    Engine(std::string searchValue);

    void startDrilling();

    // void setSearchValue(string);

    // void

    std::vector<FileInfo> getResults();

    bool isCrawling();
    
    void waitDrilling();

    void stopDrillingSync();

    void stopDrillingAsync();
};
} // namespace Drill
