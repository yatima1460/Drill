#pragma once

#include <string>
#include <vector>
#include <thread>

namespace Drill
{
class Engine
{

    std::vector<std::thread*> crawlers;
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
