module API;

import std.algorithm : canFind, filter, map;
import std.container : Array;
import std.array : array, split;
import std.process : executeShell;
import std.string : indexOf;
import std.regex: Regex, regex;
import std.file : dirEntries, SpanMode, DirEntry, readText, FileException;
import std.path : buildPath;
import std.conv: to;

import Utils : readListFiles;
import Logger : Logger;
import Crawler : Crawler;
import FileInfo : FileInfo;


class DrillAPI
{

    unittest
    {
        DrillAPI drill = new DrillAPI("../../Assets");
        assert(drill.DRILL_VERSION == readText("../../DRILL_VERSION"));
        assert(drill.PRIORITY_LIST == readListFiles("../../Assets/PriorityLists"));
        assert(drill.BLOCK_LIST == readListFiles("../../Assets/BlockLists"));
        assert(drill.PRIORITY_LIST_REGEX.length != 0);
    }


private:

    Array!Crawler threads;

    immutable(string[]) BLOCK_LIST;
    immutable(string[]) PRIORITY_LIST;
    const(Regex!char[]) PRIORITY_LIST_REGEX;

public:
    static immutable(string) DRILL_VERSION = import("DRILL_VERSION");
    static immutable(string) BUILD_TIME = __TIMESTAMP__;
    static immutable(string) GITHUB_URL = "https://github.com/yatima1460/Drill";
    static immutable(string) WEBSITE_URL = "https://www.drill.santamorena.me";
    static immutable(string) AUTHOR_URL = "https://www.linkedin.com/in/yatima1460/";
    static immutable(string) AUTHOR_NAME = "Federico Santamorena";
    

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
            PRIORITY_LIST = cast(immutable(string[]))readListFiles(buildPath(assetsDirectory,"PriorityLists"));
            this.PRIORITY_LIST_REGEX = PRIORITY_LIST[].map!(x => regex(x)).array; 
        }
        catch (FileException fe)
        {
            Logger.logError(fe.toString());
            Logger.logError("Error when trying to read priority lists, will default to an empty list");
        }
    }

    // void startCrawler(immutable(string) mountpoint, immutable(string) search,
    //         void delegate(immutable(FileInfo) result) resultFound)
    // {

    // }

    // void startCrawler(immutable(string) mountpoint, immutable(string) search,
    //         void delegate(immutable(FileInfo) result) resultFound)
    // {

    // }

    /**
    Starts the crawling, every crawler will filter on its own.
    Use the resultFound callback as an event to know when a crawler finds a new result.
    You can call this without stopping the crawling, the old crawlers will get stopped automatically.
    If a crawling is already in progress the current one will get stopped asynchronously and a new one will start.

    Params:
        search = the search string, case insensitive, every word (split by space) will be searched in the file name
        resultFound = the delegate that will be called when a crawler will find a new result
    */
    void startCrawling(immutable(string) search, shared(void delegate(immutable(FileInfo) result)) resultFound)
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
    Notifies the crawlers to stop and clears the crawlers array stored inside DrillAPI
    This function is non-blocking.
    If no crawling is currently underway this function will do nothing.
    */
    void stopCrawlingAsync()
    {
        foreach (Crawler crawler; this.threads)
            crawler.stopAsync();
        this.threads.clear(); // TODO: if nothing has a reference to a thread does the thread get GC-ed?
    }

    /**
    This function stops all the crawlers and will return only when all of them are stopped
    */
    void stopCrawlingSync() 
    {
        foreach (Crawler crawler; this.threads)
            crawler.stopAsync();
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
    

    static @system string[] _getMountPoints()
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
            auto result = array(ls.output.split("\n").filter!(x => canFind(x, "/"))).idup;
            //debug{logConsole("Mount points found: "~to!string(result));}
            return cast(string[])result;
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
            auto result = array(ls.output.split("\n").filter!(x => x.length > startColumn).map!(x => x[startColumn .. $]).filter!(x => canFind(x, "/"))).idup;
            //debug{logConsole("Mount points found: "~result);}
            return cast(string[])result;
        }

        version (Windows)
        {
            immutable auto ls = executeShell("wmic logicaldisk get caption");
            if (ls.status != 0)
            {
                Logger.logError("Can't retrieve mount points, will just scan 'C:'");
                return ["C:"];
            }

            auto result = array(map!(x => x[0 .. 2])(ls.output.split("\n").filter!(x => canFind(x, ":")))).idup;
            //debug{logConsole("Mount points found: "~result);}
            return cast(string[])result;
        }
    }
    import std.functional : memoize;
    alias getMountPoints = memoize!_getMountPoints;

    /**
    A crawler is active when it's scanning something.
    If a crawler cleanly finished its job it's not considered active.
    If a crawler crashes (should never happen) it's not considered active.
    Minimum: 0
    Maximum: length of total number of mountpoints unless the user started the crawlers manually

    Returns: number of crawlers active
    
    */
    const @nogc @safe immutable(uint) getActiveCrawlersCount()
    {
        int active = 0;
        for (int i = 0; i < threads.length; i++)
        {   
            if (threads[i].isCrawling())
                active++;
        }
        return active;
    }


}
