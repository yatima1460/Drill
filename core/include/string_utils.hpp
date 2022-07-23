#pragma once

#include <string>

namespace Drill
{
    namespace string_utils
    {
        bool tokenSearch(std::string main, std::string tokens);

        std::string to_lower(const std::string &);
    } // namespace string_utils
} // namespace Drill