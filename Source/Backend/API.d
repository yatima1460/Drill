

import std.algorithm : canFind, filter, map;
import std.container : Array, SList;
import std.array : array, split;

import std.string : indexOf;
import std.regex: Regex, regex;
import std.file : dirEntries, SpanMode, DirEntry, readText, FileException;
import std.path : buildPath;
import std.conv: to;

import Utils : readListFiles;
import Logger : Logger;
import Crawler : Crawler;
import FileInfo : FileInfo;
import ApplicationInfo : ApplicationInfo;


immutable(string) DRILL_AUTHOR_NAME = "Federico Santamorena";
immutable(string) DRILL_GITHUB_URL  = "https://github.com/yatima1460/Drill";
immutable(string) DRILL_VERSION     = import("DRILL_VERSION");
immutable(string) DRILL_AUTHOR_URL  = "https://www.linkedin.com/in/yatima1460/";
immutable(string) DRILL_WEBSITE_URL = "https://www.drill.santamorena.me";
immutable(string) DRILL_BUILD_TIME  = __TIMESTAMP__;


struct DrillData
{
    immutable(string) ASSETS_DIRECTORY;
    immutable(string[]) BLOCK_LIST;
    immutable(string[]) PRIORITY_LIST;
    const(Regex!char[]) PRIORITY_LIST_REGEX;
    bool singlethread;
}

struct DrillContext
{
    string search_value;
    SList!Crawler threads;
}


/**
A crawler is active when it's scanning something.
If a crawler cleanly finished its job it's not considered active anymore.
If a crawler crashes (should never happen, generally only for permission problems) it's not considered active.
Minimum: 0
Maximum: length of total number of mountpoints unless the user started the crawlers manually

Returns: number of crawlers active

*/
@nogc @safe immutable(uint) activeCrawlersCount(DrillContext context)
{
    int active = 0;
    foreach (thread; context.threads)
        active += thread.isCrawling();
    return active;
}


/*
Notifies the crawlers to stop and clears the crawlers array stored inside DrillAPI
This function is non-blocking.
If no crawling is currently underway this function will do nothing.
*/
@nogc void stopCrawlingAsync(DrillContext context)
{
    foreach (Crawler crawler; context.threads)
        crawler.stopAsync();
    context.threads.clear(); // TODO: if nothing has a reference to a thread does the thread get GC-ed?
}


/**
This function will return only when all crawlers finished their jobs or were stopped
This function does not stop the crawlers!!!
*/
void waitForCrawlers(DrillContext context)
{
    Logger.logInfo("Waiting for "~to!string(activeCrawlersCount(context))~" crawlers to stop");
    foreach (Crawler crawler; context.threads)
    {
        Logger.logInfo("Waiting for crawler "~to!string(crawler)~" to stop");
        import core.thread : ThreadException;
        try
        {
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
void stopCrawlingSync(DrillContext context)
{
    foreach (Crawler crawler; context.threads)
        crawler.stopAsync();
    waitForCrawlers(context);
}


/**
Starts the crawling, every crawler will filter on its own.
Use the resultFound callback as an event to know when a crawler finds a new result.
You can call this without stopping the crawling, the old crawlers will get stopped automatically.
If a crawling is already in progress the current one will get stopped asynchronously and a new one will start.

Params:
    search = the search string, case insensitive, every word (split by space) will be searched in the file name
    resultFound = the delegate that will be called when a crawler will find a new result
*/
DrillContext startCrawling(const(DrillData) data, immutable(string) searchValue, immutable(void function(immutable(FileInfo) result, void* userObject)) resultCallback, void* userObject)
{
    import Utils : get_mountpoints;
    DrillContext c = {searchValue};
    debug Logger.logWarning("user_object is null");
    foreach (immutable(string) mountpoint; get_mountpoints())
    {
        Crawler crawler = new Crawler(mountpoint, data.BLOCK_LIST, data.PRIORITY_LIST_REGEX, resultCallback, searchValue,userObject);
        if (data.singlethread)
            crawler.run();
        else
            crawler.start();
        c.threads.insertFront(crawler);
    }
    return c;
}


/*
Loads Drill data to be used in any crawling
*/
DrillData loadData(immutable(string) assets_directory)
{
    import Utils : get_mountpoints;
    Logger.logDebug("DrillAPI " ~ DRILL_VERSION);
    Logger.logDebug("Mount points found: "~to!string(get_mountpoints()));
    auto blockListsFullPath = buildPath(assets_directory,"BlockLists");

    Logger.logDebug("Assets Directory: " ~ assets_directory);
    Logger.logDebug("blockListsFullPath: " ~ blockListsFullPath);

    string[] BLOCK_LIST; 
    try
    {
        BLOCK_LIST = readListFiles(blockListsFullPath);
    }
    catch (FileException fe)
    {
        Logger.logError(fe.toString());
        Logger.logError("Error when trying to load block lists, will default to an empty list");
    }

    string[] PRIORITY_LIST;
    Regex!char[] PRIORITY_LIST_REGEX;
    try
    {
        PRIORITY_LIST = readListFiles(buildPath(assets_directory,"PriorityLists"));
        PRIORITY_LIST_REGEX = PRIORITY_LIST[].map!(x => regex(x)).array;
    }
    catch (FileException fe)
    {
        Logger.logError(fe.toString());
        Logger.logError("Error when trying to read priority lists, will default to an empty list");
    }

    DrillData dd = {
        assets_directory,
        cast(immutable(string[]))BLOCK_LIST,
        cast(immutable(string[]))PRIORITY_LIST,
        PRIORITY_LIST_REGEX
    };
    return dd;
}






