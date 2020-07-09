#pragma once

#include <vector>

#include "CrawlerData.hpp"

// Given a list of crawlers will return the active ones
int ActiveCrawlersCount(const std::vector<CrawlerData> crawlers);
