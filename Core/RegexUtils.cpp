#include "RegexUtils.hpp"

#include <spdlog/spdlog.h>

bool validateRegex(const std::string regex)
{
    const char *validator = R"###(
^((?:(?:[^?+*{}()[\]\\|]+|\\.|\[(?:\^?\\.|\^[^\\]|[^\\^])(?:[^\]\\]+|\\.)*\]|\((?:\?[:=!]|\?<[=!]|\?>)?(?1)??\)|\(\?(?:R|[+-]?\d+)\))(?:(?:[?+*]|\{\d+(?:,\d*)?\})[?+]?)?|\|)*)$
)###";

    try
    {
        std::regex self_regex(validator, std::regex::extended);

        try
        {
            return std::regex_search(regex, self_regex);
        }
        catch (std::regex_error &e)
        {
            return false;
        }
    }
    catch (std::regex_error &e)
    {
        spdlog::error("Regex validator errored: {0}", e.what());
        spdlog::error(validator);
        return false;
    }
}


bool isInRegexList(const std::vector<std::regex>& list, const std::string& str)
{

    if (list.empty())
    {
        //spdlog::warn("isInRegexList: empty regex list as input for string `{0}`", str);
        return false;
    }
    if (str.empty())
    {
        //spdlog::warn("isInRegexList: empty string");
        return false;
    }


    
    for (const auto& regex : list)
    {
        if (std::regex_search(str, regex))
        {
            //spdlog::trace("isInRegexList: `{0}`", str);
            return true;
        }
            
    }



    return false;
}