

#pragma once

#include <string>
#include <regex>

bool validateRegex(const std::string regex);




bool isInRegexList(const std::vector<std::regex>& list, const std::string& str);