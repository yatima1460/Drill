#pragma once

#include <string>
#include <vector>
#include <thread>
#include "Config.hpp"

namespace Drill
{
class Engine
{

    std::vector<std::thread*> crawlers;
    DrillConfig configs;
    // string searchValue, CrawlerCallback resultCallback, void* userObject

    std::string searchValue;

public:
    Engine(std::string searchValue);

    void startDrilling();

    // void setSearchValue(string);

    // void

    void stopDrillingSync();

    void stopDrillingAsync();
};
} // namespace Drill
