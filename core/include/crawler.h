#pragma once

#include <iostream>
#include <string>

// #include <spdlog/spdlog.h>

#include "result.h"

void drill_crawler_scan(std::string mountpoint, std::string searchValue,
                        void (*resultsCallback)(struct drill_result results));
