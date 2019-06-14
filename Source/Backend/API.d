module API;

import std.container : Array;

import std.array : array;
import std.array : split;

import std.process : executeShell;
import std.string : indexOf;

import std.algorithm : canFind, filter, map;


import Utils : readListFiles;
// import Utils : logConsole;

import Logger : Logger;

import Crawler : Crawler;
import FileInfo : FileInfo;

import std.file : dirEntries, SpanMode, DirEntry, readText, FileException;
import std.path : buildPath;

// TODO: register delegate for messagebox show called from UI frontend library

import std.regex: Regex, regex;
import std.conv: to;
import std.algorithm : map;


/*
NOTE: the basic idea is to use logConsole inside debug{ } like a log trace, only when it's something that happens more than once, like a crawler finding files
Errors should always be logged and should never be inside debug{ }
*/


class DrillAPI
{


private:
    Array!Crawler threads;
    immutable(string[]) BLOCK_LIST;
    
    const(Regex!char[]) PRIORITY_LIST_REGEX;
    static string DRILL_VERSION = import("DRILL_VERSION");

public:



    /**
    Initializes a new Drill search engine
    */
    this(immutable(string) assetsDirectory)
    {
        Logger.logDebug("DrillAPI " ~ DRILL_VERSION);
        Logger.logDebug("Mount points found: "~to!string(getMountPoints()));
        auto blockListsFullPath = buildPath(assetsDirectory,"BlockLists");
        
        Logger.logDebug("Assets Directory: " ~ assetsDirectory);
        Logger.logDebug("blockListsFullPath: " ~ blockListsFullPath);

        try
        {
            BLOCK_LIST = cast(immutable(string[]))readListFiles(blockListsFullPath);
        }
        catch (FileException fe)
        {
            Logger.logError(fe.toString());
            Logger.logError("Error when trying to load block lists, will default to an empty list");
        }
        try
        {
            immutable(string[]) PRIORITY_LIST = cast(immutable(string[]))readListFiles(buildPath(assetsDirectory,"PriorityLists"));
            this.PRIORITY_LIST_REGEX = PRIORITY_LIST[].map!(x => regex(x)).array; 
        }
        catch (FileException fe)
        {
            Logger.logError(fe.toString());
            Logger.logError("Error when trying to read priority lists, will default to an empty list");
        }
    }

    void startCrawler(immutable(string) mountpoint, immutable(string) search,
            void delegate(immutable(FileInfo) result) resultFound)
    {

    }

    void startCrawler(immutable(string) mountpoint, immutable(string) search,
            void delegate(immutable(FileInfo) result) resultFound)
    {

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
    void startCrawling(immutable(string) search, void delegate(immutable(FileInfo) result) resultFound)
    {
        // stop previous crawlers
        this.stopCrawlingAsync();

        foreach (immutable(string) mountpoint; getMountPoints())
        {
            Crawler crawler = new Crawler(mountpoint, this.BLOCK_LIST, this.PRIORITY_LIST_REGEX, resultFound, search);
            crawler.start();
            this.threads.insertBack(crawler);
        }
    }

    /*
    Notifies the crawlers to stop.
    This function is non-blocking.
    If no crawling is currently underway this function will do nothing.
    */
    void stopCrawlingAsync()
    {
        foreach (Crawler crawler; this.threads)
        {
            crawler.stopAsync();
        }
        this.threads.clear(); // TODO: if nothing has a reference to a thread does the thread get GC-ed?
    }

    /**
    This function stops all the crawlers and will return only when all of them are stopped
    */
    void stopCrawlingSync()
    {
        stopCrawlingAsync();
        waitForCrawlers();
    }

    /**
    This function will return only when all crawlers finished their jobs or were stopped
    This function does not stop the crawlers!!!
    */
    void waitForCrawlers()
    {
        Logger.logInfo("Waiting for "~to!string(getActiveCrawlersCount())~" crawlers to stop");
        foreach (Crawler crawler; this.threads)
        {
            Logger.logInfo("Waiting for crawler "~to!string(crawler)~" to stop");
            crawler.join();
            Logger.logInfo("Crawler "~to!string(crawler)~" stopped");
        }
        Logger.logInfo("All crawlers stopped.");
    }

    /**
    Returns the mount points of the current system

    Returns: immutable array of full paths

    It's not assured that every mount point is a physical disk
    */
    static immutable(string[]) getMountPoints()
    {
        version (linux)
        {
            // df catches network mounted drives like NFS
            // so don't use lsblk here
            immutable auto ls = executeShell("df -h --output=target");
            if (ls.status != 0)
            {
                Logger.logError("Can't retrieve mount points, will just scan '/'");
                return ["/"];
            }
            immutable auto result = array(ls.output.split("\n").filter!(x => canFind(x, "/"))).idup;
            //debug{logConsole("Mount points found: "~to!string(result));}
            return result;
        }

        version (OSX)
        {
            immutable auto ls = executeShell("df -h");
            if (ls.status != 0)
            {
                Logger.logError("Can't retrieve mount points, will just scan '/'");
                return ["/"];
            }
            immutable auto startColumn = indexOf(ls.output.split("\n")[0], 'M');
            immutable auto result = array(ls.output.split("\n").filter!(x => x.length > startColumn).map!(x => x[startColumn .. $]).filter!(x => canFind(x, "/"))).idup;
            //debug{logConsole("Mount points found: "~result);}
            return result;
        }

        version (Windows)
        {
            immutable auto ls = executeShell("wmic logicaldisk get caption");
            if (ls.status != 0)
            {
                Logger.logError("Can't retrieve mount points, will just scan 'C:'");
                return ["C:"];
            }

            immutable auto result = array(map!(x => x[0 .. 2])(ls.output.split("\n").filter!(x => canFind(x, ":")))).idup;
            //debug{logConsole("Mount points found: "~result);}
            return result;
        }
    }

    /**
    A crawler is active when it's scanning something.
    If a crawler cleanly finished its job it's not considered active.
    If a crawler crashes (should never happen) it's not considered active.
    Minimum: 0
    Maximum: length of total number of mountpoints unless the user started the crawlers manually

    Returns: number of crawlers active
    
    */
    immutable(ulong) getActiveCrawlersCount() const
    {
        return array(this.threads[].filter!(x => x.isCrawling())).length;
    }

    /**
    Returns the version of DrillAPI
    */
    static immutable(string) getVersion() @safe @nogc
    {
        return DRILL_VERSION;
    }

}
