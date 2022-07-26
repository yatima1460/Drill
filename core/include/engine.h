#pragma once


#include <thread>
#include <vector>

#include "crawler.h"

std::vector<std::thread *> drill_search_async(const char* search_value,
                                              void (*results_callback)(struct drill_result result));

void drill_search_wait(std::vector<std::thread *> crawlers);
