#pragma once

#include <string>
#include <thread>
#include <vector>

#include "crawler.hpp"

namespace Drill
{

    namespace engine
    {
        void search(std::string searchValue, void (*resultsCallback)(result::result results));
    }
} // namespace Drill
