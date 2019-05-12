module drill.core.api;

import drill.core.crawler : Crawler;
import drill.core.fileinfo : FileInfo;

import std.container : Array;

import std.array : array;

import std.process : executeShell;
import std.array : split;
import std.algorithm : canFind, filter;


class DrillAPI
{

private:
    Array!Crawler threads;
    immutable(string[]) blocklist;
    

public:

    this()
    {
        this.threads = Array!Crawler();
        import std.file : dirEntries, SpanMode, DirEntry, readText, FileException;

        // we use a boolean flag as a proxy to keep the blocklist immutable
        // otherwise we would have two initializations
      
        string[] temp_blocklist = [];
        try
        {
          


            auto blocklists_file = dirEntries(DirEntry("assets/blocklists"),
                    SpanMode.shallow, true);

           

            foreach (string partial_blocklist; blocklists_file)
            {
                temp_blocklist ~= readText(partial_blocklist).split("\n");
            }
            
          
           
        }
        catch (FileException fe)
        {
            // TODO: notify this happened
        }

     
            this.blocklist = temp_blocklist.idup;
       
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
    void startCrawling(immutable(string) search, void function(immutable(FileInfo) result) resultFound)
    {
        this.stopCrawlingAsync();
        

        import std.algorithm : map;
        immutable string[] mountpoints = this.getMountPoints();

        foreach (string mountpoint; mountpoints)
        {
            // // debug
            // // {
            // //     log.info("Starting thread for: ", mountpoint);
            // // }
            Array!string crawler_exclusion_list = Array!string(blocklist);

            // for safety measure add the mount points minus itself to the exclusion list
            string[] cp_tmp = mountpoints[].filter!(x => x != mountpoint)
                .map!(x => "^" ~ x ~ "$")
                .array;
            // debug
            // {
            //     log.info(join(cp_tmp, " "));
            // }
            crawler_exclusion_list ~= cp_tmp;
            // assert mountpoint not in crawler_exclusion_list, "crawler mountpoint can't be excluded";

            import std.regex;

            // debug
            // {
            //     log.info("Compiling Regex...");
            // }
            Regex!char[] regexes = crawler_exclusion_list[].map!(x => regex(x)).array;
            // debug
            // {
            //     log.info("Compiling Regex... DONE");
            // }
            auto crawler = new Crawler(mountpoint, regexes, resultFound,search);
            crawler.start();
            this.threads.insertBack(crawler);
        }
    }

    /**
    Notifies the crawlers to stop.
    This action is non-blocking.
    If no crawling is currently underway this will do nothing.
    */
    void stopCrawlingAsync()
    {
        foreach (Crawler crawler; this.threads)
        {
            crawler.stopAsync();
        }
        this.threads.clear(); // TODO: if nothing has a reference to a thread does the thread get GC-ed?
    }

    void waitForCrawlers()
    {
        foreach (Crawler crawler; this.threads)
        {
            crawler.join();
        }
    }

    /**
    Returns the mount points the crawlers will scan when started with startSearch

    Returns: immutable array of full paths
    */
    immutable(string[]) getMountPoints()
    {
        version (linux)
        {
            // df catches network mounted drives like NFS
            // so don't use lsblk here
            immutable auto ls = executeShell("df -h --output=target");
            if (ls.status != 0)
            {
                // TODO: messagebox can't retrieve mountpoints will just scan /
                return ["/"];
            }
            immutable auto result = array(ls.output.split("\n").filter!(x => canFind(x, "/"))).idup;
            return result;
        }
    }

    /**
    A crawler is active when it's scanning something.
    If a crawler cleanly finished its job it's considered not active.
    If a crawler crashes (should never happen) it's not considered active.

    Returns: number of crawlers active
    */
    ulong getActiveCrawlersCount()
    { 
        return array(this.threads[].filter!(x => x.isCrawling())).length;
    }

   
}
