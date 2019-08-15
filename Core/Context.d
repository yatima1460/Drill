import core.stdc.stdio : printf;
import core.stdc.stdlib : free;
import core.memory : GC;
import core.stdc.stdlib : exit; 
import core.thread : ThreadException;

import std.experimental.logger;
import std.exception : enforce;
import std.conv: to;
import std.file : dirEntries, SpanMode, DirEntry, readText, FileException;
import std.array : replace;
import std.uni : toLower;
import std.algorithm : canFind;
import std.path : baseName, dirName, extension;
import std.string : split, strip;
import std.algorithm : sort, map, filter, canFind;
import std.array : array;
import std.regex : Regex, regex, RegexMatch, match;

import Config : DrillConfig;
import Config : loadMime;
import Crawler : Crawler;
import Crawler : CrawlerCallback;
import Crawler : matchesRegexList;

import FileInfo : FileInfo;
import MatchingFunctions : MatchingFunction, isFileNameMatchingSearchString, isFileContentMatchingSearchString;
import Utils : getMountpoints;

import core.sync.barrier : Barrier;

/++
    This struct represents an active Drill search, 
    it holds a pool of crawlers and the current state, 
    like the searched value
+/
pure nothrow @nogc class DrillContext
{
      bool stopping;
      Barrier barrier;

    /++
        The value to search in the crawling, will be checked as lowercase against lowercase filenames
    +/
    string searchValue;
    @safe invariant 
    { 
        assert(searchValue !is null, "Search value has become null in DrillContext"); 
        assert(searchValue.length > 0, "Search value has 0 length in DrillContext");
    }
    
    /++
        A list of crawlers
    +/
    Crawler[] threads;
    @safe invariant
    {
        assert(threads.length >= 0 && threads.length <= getMountpoints().length, "Crawlers length is over mountpoints length");
    }

    /++
        Optional userObject to pass to the resultCallback
    +/
    void* userObject;


    /++
        Notifies the crawlers to stop and clears the crawlers array stored inside DrillContext
        This function is non-blocking.
        If no crawling is currently underway this function will do nothing.
    +/
    @safe void stopCrawlingAsync()
    {
        info("Requested to stop all crawlers asynchronously");
        warning(this.threads.length == 0,"Requested to stop crawlers when the number of crawlers is 0");

        foreach (Crawler crawler; this.threads)
            crawler.stopAsync();
        //drillContext.threads = []; 
        // FIXME: if nothing has a reference to a thread does the thread get GC-ed?
    }


    /++
        A crawler is active when it's scanning something.
        If a crawler cleanly finished its job it's not considered active anymore.
        If a crawler crashes (should never happen, generally only for permission problems) it's not considered active.
        Minimum: 0
        Maximum: length of total number of mountpoints unless the user started the crawlers manually

        Returns: number of crawlers active
    +/
    @safe nothrow @nogc immutable(uint) activeCrawlersCount() 
    {
        int active = 0;
        assert(this.threads !is null);
        foreach (thread; this.threads)
        {
            assert(thread !is null);
            active += thread.isCrawling();
        }
           
        return active;
    }



    /++
        This function will return only when all crawlers finished their jobs or were stopped
        This function does not stop the crawlers!!!
    +/
    @trusted void waitForCrawlers()
    {

     
        info("Waiting for crawlers to stop, "~to!string(this.activeCrawlersCount())~" are running now, "~to!string(this.threads.length)~" were spawned");
        warning(this.threads.length == 0,"trying to wait crawlers when the number of crawlers is 0");

        foreach (Crawler crawler; this.threads)
        {
            import core.thread : Thread;
            if (Thread.getThis() == crawler)
            {
                infof("'%s' requested to stop the crawling",crawler);
                //a crawler requested the stopping


                continue;
            }
            
            try
            {
                //FIXME: if for whatever reason the crawler is not started this will SEGFAULT

                infof("Waiting for crawler %s to stop...", to!string(crawler));
                if (crawler.isRunning())
                    crawler.join();     
                infof("Waiting for crawler %s concluded", to!string(crawler));
                
                //fatal(crawler.isRunning(), "trying to destroy a Crawler thread that is running");
               // fatal(crawler.isCrawling(), "trying to destroy a Crawler that is crawling");

                // infof("Crawler %s will now be destroyed...", to!string(crawler));
                // crawler.destroy();
                // infof("Crawler %s has been destroyed", to!string(crawler));
            }
            catch(ThreadException e)
            {
                critical("Thread "~crawler.toString()~" crashed when joining with message: "~e.msg);
            }
            
        }
        info("All crawlers stopped.");

    //  crawlers = [];
    }

    import std.stdio : writeln;

    /++
    This function stops all the crawlers and will return only when all of them are stopped
    +/
    @safe void stopCrawlingSync()
    {
        info("Requested to stop all crawlers synchronously");
        
        if (this.stopping)
        {
            fatal("Sync stop already requested");
            
        
            return;
        }
        
    
        this.stopping = true;

        foreach (Crawler crawler; this.threads)
        {
            assert(crawler !is null);
            crawler.stopAsync();
        }   
           
        this.waitForCrawlers();


        debug foreach (Crawler crawler; this.threads)
        {
            assert(crawler.isRunning() == false);
            assert(crawler.isCrawling() == false);
        }   
        


        //assert(this.activeCrawlersCount() == 0,to!string(this.activeCrawlersCount()));
        info("All crawlers stopped");
    }
}









// /++
// This function stops all the crawlers and will return only when all of them are stopped
// +/
// @system void stopCrawlingSyncFromCrawler(ref Crawler[] crawlers)
// {
//     import Crawler : Crawler; 
//     foreach (Crawler crawler; crawlers)
//         crawler.stopAsync();
//     waitForCrawlers(crawlers);
//     info("all crawlers stopped");
// }











        //printf("startCrawling foreach loop userObject:%p\n",userObject);

/++
Starts the crawling, every crawler will filter on its own.
Use the resultFound callback as an event to know when a crawler finds a new result.

Params:
    search = the search string, case insensitive, every word (split by space) will be searched in the file name
    resultFound = the delegate that will be called when a crawler will find a new result
+/

@trusted DrillContext startCrawling(const(DrillConfig) config, immutable(string) searchValue, CrawlerCallback resultCallback, void* userObject)
in (searchValue !is null, "the search string can't be null")
in (searchValue.length > 0, "the search string can't be empty")
in (resultCallback !is null, "the search callback can't be null")
{
    DrillContext c = new DrillContext();

    MatchingFunction matchingFunction = null;
    if (searchValue == "content:")
    {
        return c;
    }
    if (searchValue.canFind("content:"))
    {
        matchingFunction = &isFileContentMatchingSearchString;
        c.searchValue = searchValue.split(":")[1];
    }
    else
    {
        matchingFunction = &isFileNameMatchingSearchString;
        c.searchValue = searchValue;
    }

    assert(c.searchValue !is null);
    assert(c.searchValue.length > 0);
    
    c.userObject = userObject;

    if (c.userObject == null)
        warning("user_object is null");

    // i = case insensitive
    auto blocklistRegex = config.BLOCK_LIST.map!(x => regex(x,"i")).array;

    //getMountpoints.map!(x => !matchesRegexList(blocklistRegex,mountpoint))
    auto mp = getMountpoints();
    c.barrier = new Barrier(cast(uint)mp.length+1);

    foreach (immutable(string) mountpoint; mp)
    {
        if (matchesRegexList(blocklistRegex, mountpoint))
        {
            trace("Crawler mountpoint is in the blocklist, the crawler will stop.",mountpoint);
            c.barrier.wait();
            continue;
        }
        Crawler crawler = new Crawler(
            mountpoint, 
            blocklistRegex, 
            config.PRIORITY_LIST_REGEX, 
            resultCallback, 
            c.searchValue, 
            c.userObject, 
            matchingFunction,
            c.barrier
        );
        crawler.isDaemon(false);
        crawler.name = mountpoint;
        //crawler.run();
      
        crawler.start();
        c.threads ~= crawler;
    }
    info("Waiting for all crawlers to run...");
    c.barrier.wait(),
    info("Finished spawning crawlers");
    return c;
}
