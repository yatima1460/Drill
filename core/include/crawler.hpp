#pragma once

#include <iostream>
#include <string>

#include <spdlog/sinks/stdout_color_sinks.h>
#include <spdlog/spdlog.h>

#include "result.hpp"

namespace Drill
{

    namespace crawler
    {
        void scan(std::string mountpoint, std::string searchValue,
                  void (*resultsCallback)(struct drill_result results), std::shared_ptr<spdlog::logger>);

    }

} // namespace Drill
