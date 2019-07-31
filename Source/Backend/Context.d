import Config : DrillConfig;
import FileInfo : FileInfo;
import std.variant : Variant;
import Crawler : Crawler;
import std.experimental.logger;

/++
This struct represents an active Drill search, 
it holds a pool of crawlers and the current state, 
like the searched value
+/
pure nothrow @nogc struct DrillContext
{

    /++
    The value to search in the crawling, will be checked as lowercase against lowercase filenames
    +/
    string searchValue;
    invariant 
    { 
        assert(searchValue !is null, "Search value has become null in DrillContext"); 
        assert(searchValue.length > 0, "Search value has 0 length in DrillContext");
    }
    
    /++
    A list of crawlers
    +/
    Crawler[] threads;
    invariant
    {
        assert(threads.length >= 0 && threads.length <= getMountpoints().length, "Crawlers length is over mountpoints length");
    }

    /++
    Optional userObject to pass to the resultCallback
    +/
    void* userObject;

    // ~this()
    // {
    //     stopCrawlingSync(threads);
    // }
}


/++
A crawler is active when it's scanning something.
If a crawler cleanly finished its job it's not considered active anymore.
If a crawler crashes (should never happen, generally only for permission problems) it's not considered active.
Minimum: 0
Maximum: length of total number of mountpoints unless the user started the crawlers manually

Returns: number of crawlers active
+/
pure nothrow @safe @nogc immutable(uint) activeCrawlersCount(const Crawler[] crawlers) 
{
    int active = 0;
    foreach (thread; crawlers)
        active += thread.isCrawling();
    return active;
}


/++
Notifies the crawlers to stop and clears the crawlers array stored inside DrillContext
This function is non-blocking.
If no crawling is currently underway this function will do nothing.
+/
@system @nogc void stopCrawlingAsync(ref Crawler[] crawlers)
{
    import Crawler : Crawler; 
    foreach (Crawler crawler; crawlers)
        crawler.stopAsync();
    crawlers = []; 
    // FIXME: if nothing has a reference to a thread does the thread get GC-ed?
}


/++
This function will return only when all crawlers finished their jobs or were stopped
This function does not stop the crawlers!!!
+/
@system void waitForCrawlers(ref Crawler[] crawlers)
{
    import Crawler : Crawler; 
    
    import std.conv: to;
    info("Waiting for "~to!string(activeCrawlersCount(crawlers))~" crawlers to stop");
    foreach (Crawler crawler; crawlers)
    {
        info("Waiting for crawler "~to!string(crawler)~" to stop");
        import core.thread : ThreadException;
        try
        {
            //FIXME: if for whatever reason the crawler is not started this will SEGFAULT
            crawler.join();     
            info("Crawler "~to!string(crawler)~" stopped");
            crawler.destroy();
        }
        catch(ThreadException e)
        {
            critical("Thread "~crawler.toString()~" crashed when joining");
            critical(e.msg);
        }
        
    }
    info("All crawlers stopped.");

    crawlers = [];
}


/++
This function stops all the crawlers and will return only when all of them are stopped
+/
@system void stopCrawlingSync(ref Crawler[] crawlers)
{
    import Crawler : Crawler; 
    foreach (Crawler crawler; crawlers)
        crawler.stopAsync();
    waitForCrawlers(crawlers);
    info("all crawlers stopped");
}

import Utils : getMountpoints;
import Crawler : CrawlerCallback;
/++
Starts the crawling, every crawler will filter on its own.
Use the resultFound callback as an event to know when a crawler finds a new result.

Params:
    search = the search string, case insensitive, every word (split by space) will be searched in the file name
    resultFound = the delegate that will be called when a crawler will find a new result
+/
@system  DrillContext* startCrawling(in const(DrillConfig) config, 
                                   in immutable(string) searchValue, 
                                   in CrawlerCallback resultCallback, 
                                   in void* userObject)
in (searchValue !is null, "the search string can't be null")
in (searchValue.length > 0, "the search string can't be empty")
in (resultCallback !is null, "the search callback can't be null")
out (c;c !is null, "DrillContext can't be null after starting a search")
out (c;c.threads.length <= getMountpoints().length, "threads created number is wrong")
{
    import core.stdc.stdio : printf;
    //printf("startCrawling userObject:%p\n",userObject);
    DrillContext* c = new DrillContext();
    c.searchValue = searchValue;
    c.userObject = cast(void*)userObject;

    
    warning("user_object is null");
    foreach (immutable(string) mountpoint; getMountpoints())
    {
        import Crawler : Crawler; 
        //printf("startCrawling foreach loop userObject:%p\n",userObject);
        import Crawler : isInRegexList;
        import std.algorithm : sort, map, filter, canFind;
        import std.array : array;
        import std.regex : Regex, regex, RegexMatch, match;
        if (isInRegexList(config.BLOCK_LIST[].map!(x => regex(x,"i")).array,mountpoint))
        {
            
            info("Crawler mountpoint is in the blocklist, the crawler will stop.",mountpoint);
            continue;
        }
        Crawler crawler = new Crawler(mountpoint, config.BLOCK_LIST, config.PRIORITY_LIST_REGEX, resultCallback, searchValue, c.userObject);
        crawler.isDaemon(false);
        crawler.name = mountpoint;
        if (config.singlethread)
            crawler.run();
        else
            crawler.start();
        c.threads ~= crawler;
    }
    return c;
}
