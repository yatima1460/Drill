#pragma once

#include <string>
#include <thread>
#include <vector>

#include "crawler.hpp"

namespace Drill
{

    namespace engine
    {
        std::vector<std::thread *> search_async(std::string search_value, void (*results_callback)(struct drill_result result));
        void wait_crawlers(std::vector<std::thread *> crawlers);
    }
} // namespace Drill
