

#include "Config.hpp"
#include "System.hpp"
#include <spdlog/spdlog.h>

namespace Drill::Config
{


    /**
     * @brief Merges all txt lines into a single giant vector
     * if the path does not exist will return an empty vector
     * 
     * @param path 
     * @return std::vector<std::string> 
     */
    std::vector<std::string> readAllTextFilesInFolder(const std::string path)
    {
        std::vector<std::string> allLines;




        return allLines;
    }

    
    DrillConfig loadConfigs()
    {

        DrillConfig dc;


        if (!System::doesPathExist("~/.config/drill-search/BlockLists"))
        {
            spdlog::warn("Drill blocklists folder in ~/.config doesn't exist, falling back to default values");

            if (!System::doesPathExist("/opt/drill-search/BlockLists"))
            {
                spdlog::error("Drill blocklists in /opt/drill-search/BlockLists don't exist using empty array!!");
            }
        }
        else
        {
            dc.blockLists = readAllTextFilesInFolder(System::getHomeFolder()+"/.config/drill-search");
            spdlog::warn("Drill blocklists loaded from ~/.config are empty!");
        }
        

        // if (!System::doesPathExist("~/.config/drill-search/PriorityLists"))
        // {
        //     spdlog::warn("Drill PriorityLists in ~/.config don't exist, fallback to default values");

        //     if (!System::doesPathExist("/opt/drill-search/PriorityLists"))
        //     {
        //         spdlog::error("Drill PriorityLists in /opt/drill-search/PriorityLists don't exist using empty array!!");
        //     }
        // }
        // else
        // {
        //     /* code */
        // }
        
        // auto homeConfigs = readAllTextFilesInFolder(System::getHomeFolder()+"/.config/drill-search");

        // if (.empty())
        // {

        // }


        return dc;
    }



  

}



