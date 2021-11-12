#pragma once

#include <string>
#include <vector>

struct DrillConfig
{
    std::string ASSETS_DIRECTORY;

    
    std::vector<std::string> BLOCK_LIST;
    std::vector<std::string> PRIORITY_LIST;

    
    Regex!char[] PRIORITY_LIST_REGEX;

    bool singlethread;

    std::map<std::string,std::string> mime;
};


/**
Returns the path where the config data is stored
*/
// std::string GetConfigPath();