#pragma once


#include <spdlog/spdlog.h>
#include <spdlog/sinks/stdout_color_sinks.h>

#include <string>



#include <iostream>
#include "FileInfo.hpp"

#include "Config.hpp"


namespace Drill
{



    // Define the class of function object 
    class Crawler 
    { 
        std::shared_ptr<spdlog::logger> log;
        const std::string mountpoint;

        DrillConfig crawlerConfigs;

        std::vector<FileInfo> filesFound;

        const std::vector<std::string> mountpoints;

        std::vector<std::regex> crawlerBlocklist;
        
        // Overload () operator 
        // void operator()() 
        // { 
        //     // Do Something 
        // } 
public:

        Crawler(const std::string mountpoint, const DrillConfig cfg, const std::vector<std::string> mountpoints);


        /*
        NOTE: We don't really care about CPU time, Drill isn't CPU intensive but disk intensive,
        in this function it's not bad design that there are multiple IFs checking the same thing over and over again,
        but it's done to stop the crawling as soon as possible to have more time to crawl important files.

        ^^^ Is this really true? Maybe slow RAM and CPU can slow down too much the DMA requests too?
        */
        void run();
    };
}

