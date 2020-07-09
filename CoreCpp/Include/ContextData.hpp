#pragma once

#include <string>


/*
    This struct represents an active Drill search, 
    it holds a pool of crawlers and the current state, 
    like the searched value
*/
struct ContextData
{
    // The value to search in the crawling, will be checked as lowercase against lowercase filenames
    std::string searchValue;

    // A list of crawlers
    std::vector<CrawlerData> threads;

    // Optional userObject to pass to the resultCallback
    void* userObject;
};



