#pragma once

#include <thread>
#include <vector>

#include "crawler.h"

std::vector<struct drill_crawler_config*>
drill_search_async(const char *search_value, void (*results_callback)(struct drill_result result));

void drill_search_wait(std::vector<struct drill_crawler_config*> crawlers);

void drill_search_stop_async(std::vector<struct drill_crawler_config*> crawlers);

void drill_search_stop_sync(std::vector<struct drill_crawler_config*> crawlers);