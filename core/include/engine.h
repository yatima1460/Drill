#pragma once



#include <string>
#include <vector>
#include <thread>
#include "Config.hpp"
#include "crawler.hpp"

namespace Drill
{



namespace engine
{

    void search(std::string searchValue, void (*resultsCallback)(FileInfo results));

}

    
// class EngineObj
// {

    
//     // std::vector<Crawler*> crawlersObjects;

//     DrillConfig configs;
//     // string searchValue, CrawlerCallback resultCallback, void* userObject

  

// public:

//     const std::string SEARCH_STRING;

//     EngineObj(std::string searchValue);

//     void startDrilling();

//     // void setSearchValue(string);

//     // void

//     std::vector<FileInfo> pickupAllResults();

//     bool isCrawling();
    
//     void waitDrilling();

//     void stopDrillingSync();

//     void stopDrillingAsync();

//     ~EngineObj();
// };
} // namespace Drill
