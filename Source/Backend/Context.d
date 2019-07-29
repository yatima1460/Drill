









// import std.algorithm : canFind, filter, map;
// import std.container : Array, SList;
// import std.array : array, split;

// import std.string : indexOf;
// import std.regex: Regex, regex;
// import std.file : dirEntries, SpanMode, DirEntry, readText, FileException;
// import std.path : buildPath;
// import std.conv: to;

// import Utils : mergeAllTextFilesInDirectory;
// import Logger : Logger;
// import Crawler : Crawler;
// import FileInfo : FileInfo;
// import ApplicationInfo : ApplicationInfo;
import Config : DrillConfig;
import FileInfo : FileInfo;
import std.variant : Variant;


unittest 
{
    assert(false);
    static void resultFound(immutable(FileInfo) result, ref Variant userObject)
    in(userObject !is null)
    in(cast(int*) userObject !is null)
    in(result.fileName !is null)
    in(result.fullPath !is null)
    in(result.dateModifiedString !is null)
    in(result.fileName.length > 0)
    in(result.fullPath.length > 0)
    in(result.dateModifiedString.length > 0)
    {
        int* objInt = cast(int*)userObject;
        assert(objInt !is null);
        assert(*objInt == 42);
      
    }

    int* i = new int();
    *i = 42;

    import std.file : thisExePath;
    import std.path : dirName, buildNormalizedPath, absolutePath, buildPath;
    auto assetsFolder = buildPath(dirName(thisExePath()), "Assets");

    import Config : loadData;
    DrillContext* context = startCrawling(loadData(assetsFolder),".",&resultFound,i);

}








/**
This struct represents an active Drill search, 
it holds a pool of crawlers and the current state, 
like the searched value
*/
@nogc pure struct DrillContext
{
    // import std.container : SList;
    string search_value;
    invariant 
    { 
        assert(search_value !is null, "Search value has become null in DrillContext"); 
        assert(search_value.length > 0, "Search value has 0 length in DrillContext");
    }
    import Crawler : Crawler;
    Crawler[] threads;
    invariant
    {
        assert(threads.length >= 0 && threads.length <= getMountpoints().length, "Crawlers length is over mountpoints length");
    }
    void* userObject;

    // debug
    // {
    //     ~this()
    //     {
    //         import core.stdc.stdio;
    //         printf("DrillContext destroyed\n");
    //     }
    // }
}


/**
A crawler is active when it's scanning something.
If a crawler cleanly finished its job it's not considered active anymore.
If a crawler crashes (should never happen, generally only for permission problems) it's not considered active.
Minimum: 0
Maximum: length of total number of mountpoints unless the user started the crawlers manually

Returns: number of crawlers active
*/
@safe @nogc immutable(uint) activeCrawlersCount(in ref DrillContext context) 
{
    int active = 0;
    foreach (thread; context.threads)
        active += thread.isCrawling();
    return active;
}


/*
Notifies the crawlers to stop and clears the crawlers array stored inside DrillContext
This function is non-blocking.
If no crawling is currently underway this function will do nothing.
*/
@nogc @system void stopCrawlingAsync(ref DrillContext context)
{
    import Crawler : Crawler; 
    foreach (Crawler crawler; context.threads)
        crawler.stopAsync();
    context.threads = []; // TODO: if nothing has a reference to a thread does the thread get GC-ed?
}


/**
This function will return only when all crawlers finished their jobs or were stopped
This function does not stop the crawlers!!!
*/
@system void waitForCrawlers(ref DrillContext context)
{
    import Crawler : Crawler; 
    import Logger : Logger;
    import std.conv: to;
    Logger.logInfo("Waiting for "~to!string(activeCrawlersCount(context))~" crawlers to stop");
    foreach (Crawler crawler; context.threads)
    {
        Logger.logInfo("Waiting for crawler "~to!string(crawler)~" to stop");
        import core.thread : ThreadException;
        try
        {
            //FIXME: if for whatever reason the crawler is not started this will SEGFAULT
            crawler.join();
            Logger.logInfo("Crawler "~to!string(crawler)~" stopped");
        }
        catch(ThreadException e)
        {
            Logger.logError("Thread "~crawler.toString()~" crashed when joining");
            Logger.logError(e.msg);
        }
        
    }
    Logger.logInfo("All crawlers stopped.");
}


/**
This function stops all the crawlers and will return only when all of them are stopped
*/
@system void stopCrawlingSync(DrillContext context)
{
    import Crawler : Crawler; 
    foreach (Crawler crawler; context.threads)
        crawler.stopAsync();
    waitForCrawlers(context);
    import Logger : Logger;
    Logger.logInfo("all crawlers stopped");
}

import Utils : getMountpoints;
/**
Starts the crawling, every crawler will filter on its own.
Use the resultFound callback as an event to know when a crawler finds a new result.

Params:
    search = the search string, case insensitive, every word (split by space) will be searched in the file name
    resultFound = the delegate that will be called when a crawler will find a new result
*/
@system  DrillContext* startCrawling(in const(DrillConfig) config, 
                                   in immutable(string) searchValue, 
                                   in immutable(void function(immutable(FileInfo) result, void* userObject)) resultCallback, 
                                   in void* userObject)
in (searchValue !is null, "the search string can't be null")
in (searchValue.length > 0, "the search string can't be empty")
in (resultCallback !is null, "the search callback can't be null")
out (c;c !is null, "DrillContext can't be null after starting a search")
out (c;c.threads.length == getMountpoints().length, "threads created number is wrong")
{
    import core.stdc.stdio : printf;
    //printf("startCrawling userObject:%p\n",userObject);
    DrillContext* c = new DrillContext();
    c.search_value = searchValue;
    c.userObject = cast(void*)userObject;

    import Logger : Logger;
    debug Logger.logWarning("user_object is null");
    foreach (immutable(string) mountpoint; getMountpoints())
    {
        import Crawler : Crawler; 
        //printf("startCrawling foreach loop userObject:%p\n",userObject);
        Crawler crawler = new Crawler(mountpoint, config.BLOCK_LIST, config.PRIORITY_LIST_REGEX, resultCallback, searchValue, c.userObject);
        if (config.singlethread)
            crawler.run();
        else
            crawler.start();
        c.threads ~= crawler;
    }
    return c;
}


// /**
// Starts the crawling using the default configs
// Check the complete function for details
// */






