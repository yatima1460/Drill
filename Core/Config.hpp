#pragma once


#include <vector>
#include <string>

#define DRILLBITS_PER_ORESITE 1

namespace Drill::Config
{

    
    struct DrillConfig
    {
        std::vector<std::string> blockLists;
        std::vector<std::string> priorityLists;


    };
    /**
     * @brief Tries to create the personal configs for Drill in ~/.config
     * by copying the default ones from /opt/drill-search
     * 
     * @return true if done
     * @return false if error or already exists
     */
    //bool createDefaultConfigs();


    /**
     * @brief Same as @createDefaultConfigs but overwrites them
     * 
     */
    //bool resetDefaultConfigs();

    

    

    DrillConfig loadConfigs();
    


}