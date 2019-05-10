module drill.core.api;

import drill.core.crawler : Crawler;
import drill.core.fileinfo : FileInfo;

import std.container : Array;

import std.array : array;

import std.process : executeShell;
import std.array : split;
import std.algorithm : canFind, filter;
import std.process : spawnProcess;

class DrillAPI
{

private:
    Array!Crawler threads;

public:

    this()
    {
        this.threads = Array!Crawler();
    }

    /***
    Starts the crawling, every crawler will filter on its own.
    Use the resultFound callback as an event to know when a crawler finds a new result.
    You can call this without stopping the crawling, the old crawlers will get stopped automatically.
    If a crawling is already in progress the current one will get stopped asynchronously and a new one will start.
    */
    void startCrawling(string filter, void function(FileInfo result) resultFound)
    {
        this.stopCrawlingAsync();
        


        immutable string[] mountpoints = this.getMountPoints();

        foreach (string mountpoint; mountpoints)
        {
            // // debug
            // // {
            // //     log.info("Starting thread for: ", mountpoint);
            // // }
            // Array!string crawler_exclusion_list = Array!string(blocklist);

            // // for safety measure add the mount points minus itself to the exclusion list
            // string[] cp_tmp = mountpoints[].filter!(x => x != mountpoint)
            //     .map!(x => "^" ~ x ~ "$")
            //     .array;
            // // debug
            // // {
            // //     log.info(join(cp_tmp, " "));
            // // }
            // crawler_exclusion_list ~= cp_tmp;
            // // assert mountpoint not in crawler_exclusion_list, "crawler mountpoint can't be excluded";

            // import std.regex;

            // // debug
            // // {
            // //     log.info("Compiling Regex...");
            // // }
            // Regex!char[] regexes = crawler_exclusion_list[].map!(x => regex(x)).array;
            // // debug
            // // {
            // //     log.info("Compiling Regex... DONE");
            // // }
            // auto crawler = new Crawler(mountpoint, regexes);
            // crawler.start();
            // this.threads.insertBack(crawler);
        }
    }

    /***
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

    /***
    Returns the mount points the crawlers will scan when started with startSearch
    */
    immutable(string[]) getMountPoints()
    {
        version (linux)
        {
            immutable auto ls = executeShell("df -h --output=target");
            immutable auto result = array(ls.output.split("\n").filter!(x => canFind(x, "/"))).idup;
            return result;
        }
    }

    /***
    Opens the file using the current system implementation
    */
    void openFile(immutable(string) fullpath)
    {
        import std.stdio :stdin,stdout,stderr;
        import std.process : Config;

        version (Windows)
        {
           
            spawnProcess(["explorer", fullpath], stdin, stdout,
                    stderr, null, Config.detached, null);
        }
        version (linux)
        {
           
            spawnProcess(["xdg-open", fullpath], stdin, stdout,
                    stderr, null, Config.none, null);
        }
        version (OSX)
        {

            spawnProcess(["open", fullpath], stdin, stdout,
                    stderr, null, Config.none, null);
        }

        //TODO: return bool if successful
    }
}
