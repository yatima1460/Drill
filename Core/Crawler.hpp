#pragma once


#include <spdlog/spdlog.h>
#include <spdlog/sinks/stdout_color_sinks.h>

#include <string>



#include <iostream>


namespace Drill
{
    // Define the class of function object 
    class Crawler 
    { 
        std::shared_ptr<spdlog::logger> log;
        const std::string mountpoint;
        
        // Overload () operator 
        // void operator()() 
        // { 
        //     // Do Something 
        // } 
public:

        Crawler(std::string mountpoint) : mountpoint(mountpoint)
        {
           
            log = spdlog::stdout_color_st(mountpoint); 

            log->debug("Crawler {0} created", mountpoint);

        }


        void run()
        {
            log->info("Crawler {0} running as thread", mountpoint);
        }
    };
}

