

#include "Config.hpp"
#include "System.hpp"
#include "RegexUtils.hpp"

#include <spdlog/spdlog.h>
#include <filesystem>
#include <iostream>
#include <fstream>
#include <string>





// trim from start (in place)
void ltrim(std::string &s) {
    s.erase(s.begin(), std::find_if(s.begin(), s.end(), [](int ch) {
        return !std::isspace(ch);
    }));
}

// trim from end (in place)
void rtrim(std::string &s) {
    s.erase(std::find_if(s.rbegin(), s.rend(), [](int ch) {
        return !std::isspace(ch);
    }).base(), s.end());
}

// trim from both ends (in place)
void trim(std::string &s) {
    ltrim(s);
    rtrim(s);
}

namespace Drill
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

    namespace fs = std::filesystem;

    for (const auto &entry : fs::directory_iterator(path))
    {
        const auto filePath = entry.path();
        spdlog::trace("Config file found: {0}", filePath.c_str());

        std::ifstream file(entry.path().c_str());
      
        
        size_t n = 0;
        while (file.good())
        {
            std::string line;
            std::getline(file, line);

            trim(line);
            if (line.size() > 0 && line != "")
            {
            // if (validateRegex(line))
            // {
                allLines.push_back(line);
                 spdlog::trace("Line added: `{0}`",line);
            //     spdlog::trace("Regex is valid: `{0}`",line);
            // }
            // else
            // {
            //     spdlog::warn("Regex line #{0}: `{1}` in file `{2}` is invalid", n+1, line, path.c_str());
            // }

                
                
               
                
            }
                
            n++;
            
        }
    }

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
        spdlog::info("~/.config/drill-search/BlockLists found");
        dc.blockLists = readAllTextFilesInFolder(System::getHomeFolder() + "/.config/drill-search/BlockLists");

       if (dc.blockLists.empty())
            spdlog::warn("Drill blocklists loaded from ~/.config are empty!");

        for (auto& regexString: dc.blockLists)
        {
            try
            {
                const auto rb = std::regex(regexString);
                dc.blocklistsRegex.push_back(rb);
                spdlog::trace("Regex rule `{0}` compiled", regexString);
            }
            catch(const std::regex_error& e)
            {
                spdlog::warn("Regex rule `{0}` ignored: {1}", regexString, e.what());
            }
        }

        if (dc.blocklistsRegex.empty())
            spdlog::warn("Drill blocklists loaded from ~/.config has 0 rules");
        else
            spdlog::info("Drill blocklists loaded with {0} valid rules", dc.blocklistsRegex.size());
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

} // namespace Drill::Config
