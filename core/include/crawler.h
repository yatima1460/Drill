#pragma once

#include <iostream>
#include <string>

#include "result.h"

struct drill_crawler_config
{
    std::thread* thread;
    std::string root;
    std::string search_value;
    void (*results_callback)(struct drill_result results);
    bool stop;
};

void drill_crawler_scan(struct drill_crawler_config* config);

// Sink callback, if it's set as results callback the crawlers will stop
inline void drill_crawler_stop_callback(struct drill_result results)
{
    // black hole..
}
