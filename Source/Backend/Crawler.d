

import std.container : Array;
import core.thread : Thread;
import std.stdio : writeln;
import std.file : DirEntry, DirIterator, dirEntries, SpanMode;
import std.algorithm : sort, map, filter, canFind;
import std.path : baseName, dirName, extension;
import std.array : array, replace;
import std.conv : to;
import std.uni : toLower;
import std.regex : Regex, regex, RegexMatch, match;
import std.string : split, strip;

import Logger : Logger;
import Utils : sizeToHumanReadable, systime_to_string;
import FileInfo : FileInfo;




alias CrawlerCallback = void function(  immutable(FileInfo) result, void* userObject);

struct CrawlerData
{
    string root;
    string searchString;
    string[] blockList;

    Regex!char[] blockListRegex;
    Regex!char[] priorityListRegex;

    CrawlerCallback resultCallback;

    Variant userObject;
}


struct CrawlerContext
{
    Tid thread;
    bool running;

}

import  std.concurrency;





// ref CrawlerContext startCrawler(CrawlerData data)
// in(data.resultCallback !is null)
// out(c;c.running)
// {
//     CrawlerContext* c = new CrawlerContext();
//     c.thread = spawn(&crawl, cast(immutable)data, cast(shared)c),
//     c.running = true;
//     return c;
// }










void crawl(immutable(CrawlerData) data, shared CrawlerContext context)
{
    
}






//////////////////


@safe bool _isInRegexList(const(Regex!char[]) list, immutable(string) value)
in (value != null)
{
    foreach (ref regexrule; list)
    {
        RegexMatch!string mo = match(value, regexrule);
        if (!mo.empty())
            return true;
    }
    return false;
}



// auto composed = new Thread(&threadFunc).start();

class Crawler : Thread
{

    debug
    {
        ~this()
        {
            import core.stdc.stdio;
            printf("Crawler destroyed\n");
        }
    }

private:
    const(string) MOUNTPOINT;
    const(string) SEARCH_STRING;
    const(string[]) BLOCK_LIST;

    Regex!char[] BLOCK_LIST_REGEX;
    const(Regex!char[]) PRIORITY_LIST_REGEX;
    
    shared(bool) running;

    void function(  immutable(FileInfo) result, void* userObject) resultCallback;

    debug
    {
        long ignored_count;
    }

       const(void*) userObj;


public:

    this(
        in const(string) MOUNTPOINT, 
        in const(string[]) BLOCK_LIST,
        in const(Regex!char[]) PRIORITY_LIST_REGEX,
        in void function(immutable(FileInfo) result, void* userObject) resultCallback, 
        in immutable(string) search,
        in void* userObj
    )
    in (MOUNTPOINT != null)
    in (MOUNTPOINT.length != 0)
    in (resultCallback != null)
    in (search != null)
    in (search.length != 0)
    {
        
        //TODO: invariant root contains /

        super(&run);
        this.MOUNTPOINT = MOUNTPOINT;

        Logger.logDebug("Created",this.toString());
        Logger.logDebug("Search term '" ~ search ~ "'",this.toString());
        Logger.logDebug("Global blocklist.length = " ~ to!string(BLOCK_LIST.length),this.toString());

       
        Logger.logDebug("Global priority list length = " ~ to!string(PRIORITY_LIST_REGEX.length),this.toString());
        this.PRIORITY_LIST_REGEX = PRIORITY_LIST_REGEX;

        this.SEARCH_STRING = search;
        this.resultCallback = resultCallback;
        this.BLOCK_LIST = BLOCK_LIST;


        this.running = true;

        this.userObj = userObj;
    }

    private void noop_resultFound(immutable(FileInfo) result,void* v) const
    {

    }

    void stopAsync() @nogc
    {
        this.resultCallback = (&this.noop_resultFound).funcptr;
        this.running = false;
    }

    void stopSync() @system 
    {
        this.stopAsync();
        this.join();
    }

    pure const @safe override string toString()
    {
        return "Crawler(" ~ MOUNTPOINT ~ ")";
    }

    pure const @safe @nogc bool isCrawling()
    {
        return this.running;
    }

private:

    import std.functional : memoize;
    
    

    immutable(FileInfo) buildFileInfo(DirEntry currentFile) const
    {
        FileInfo f = {
            this.MOUNTPOINT,
            currentFile.isDir(),
            !currentFile.isDir(),
            systime_to_string(currentFile.timeLastModified()),
            dirName(currentFile.name),
            baseName(currentFile.name),
            toLower(baseName(currentFile.name)),
            extension(currentFile.name),
            currentFile.name,
            sizeToHumanReadable(currentFile.size)
        };
        return f;
    }


    bool isMatchingSearch(string filename) const pure @safe
    in (filename != null)
    {
        //FIXME: filter and remove empty strings (if the user writes "a   b")
        const string[] searchTokens = toLower(strip(SEARCH_STRING)).split(" ");
        const string fileNameLower = toLower(baseName(filename));
        foreach (token; searchTokens)
            if (!canFind(fileNameLower, token))
                return false;
        return true;
    }

//     ~this()
//    {
//       import std.stdio : writeln;
//       writeln("Crawler "~this.toString()~" de-allocated");
//    }

    public:

    /**
    NOTE: We don't really care about CPU time, Drill isn't CPU intensive but disk intensive,
    in this function it's not bad design that there are multiple IFs checking the same thing over and over again,
    but it's done to stop the crawling as soon as possible to have more time to crawl important files.
    */
    void run()
    {
        if (running == false)
            return;
        alias isInRegexList = memoize!_isInRegexList;
        assert(SEARCH_STRING != null, "the search string can't be null");
        assert(SEARCH_STRING.length != 0,"the search string can't be empty");
        //assert(this.running == false, "the crawler is marked running when it isn't even run yet");
        assert(MOUNTPOINT  != null, "the mountpoint can't be null");
        assert(MOUNTPOINT.length != 0, "the mountpoint string can't be empty");
        assert(resultCallback != null, "the result callback can't be null");

        import Utils : getMountpoints;

         // Every Crawler will have all the other mountpoints in its blocklist
        // In this way crawlers will not cross paths
        string[] cp_tmp = getMountpoints()[].filter!(x => x != MOUNTPOINT)
            .map!(x => "^" ~ x ~ "$")
            .array;
        Logger.logDebug("Adding these to the global blocklist: " ~ to!string(cp_tmp),this.toString());
        Array!string crawler_exclusion_list = Array!string(BLOCK_LIST);
        crawler_exclusion_list ~= cp_tmp;
        Regex!char[] exclusion_regexes = crawler_exclusion_list[].map!(x => regex(x)).array;
        this.BLOCK_LIST_REGEX = exclusion_regexes;

        Logger.logDebug("New crawler custom blocklist.length = " ~ to!string(BLOCK_LIST_REGEX.length),this.toString());

     
        Logger.logDebug("Started");

        import std.container.dlist : DList;
        DList!DirEntry queue;
        // if (isInRegexList(BLOCK_LIST_REGEX,MOUNTPOINT))
        // {
        //     this.running = false;
        //     Logger.logDebug("Crawler mountpoint is in the blocklist, the crawler will stop.",this.toString());
        // }
        // else
        // {
            try
            {
                queue.insertBack(DirEntry(MOUNTPOINT));
            }
            catch (Exception e)
            {
                Logger.logError(e.msg,this.toString());
                this.running = false;
            }
        // }

        while (!queue.empty() && running)
        {
            DirEntry currentDirectory = queue.front();
            queue.removeFront();
            //Logger.logDebug("Directory: " ~ currentDirectory.name,this.toString());


            if (isInRegexList(BLOCK_LIST_REGEX,currentDirectory.name))
            {
                //Logger.logDebug("Blocked: " ~ currentDirectory.name,this.toString());
                continue;
            }

            if (currentDirectory.isSymlink())
            {
                //Logger.logDebug("Symlink ignored: " ~ currentDirectory.name,this.toString());
                continue;
            }
            
            DirIterator files;
            try
            {
                files = dirEntries(currentDirectory, SpanMode.shallow, true);
            }
            catch (Exception e)
            {
               
                Logger.logError(e.msg,this.toString());
                continue;
            }

            foreach (DirEntry currentFile; files)
            {
                if (!this.running) return;
                try
                {
                    if (currentFile.isSymlink())
                    {
                        //Logger.logDebug("Symlink ignored: " ~ currentDirectory.name,this.toString());
                        continue;
                    }
                   
                    if (isInRegexList(BLOCK_LIST_REGEX, currentFile.name))
                    {
                        //Logger.logDebug("Ignored: " ~ currentFile.name,this.toString());
                        continue;
                    }
                    
                    if (currentFile.isDir())
                    {
                        if (isInRegexList(this.PRIORITY_LIST_REGEX, currentFile.name))
                        {
                            //Logger.logDebug("High priority: "~currentFile.name,this.toString());
                            queue.insertFront(currentFile);
                        }
                        else
                        {
                            //Logger.logTrace("Low priority: "~currentFile.name,this.toString());
                            queue.insertBack(currentFile);
                        }
                    }
                    
                    if (isMatchingSearch(currentFile.name))
                    //if (canFind(currentFile.name, SEARCH_STRING))
                    {
                      

                        Logger.logTrace("Matching search"~currentFile.name,this.toString());
           // auto composed = new Thread(resultCallback,buildFileInfo(currentFile)).start();
                        // try
                        // {
                        //     class ResultThread : Thread
                        //     {
                        //         DirEntry resultFile;

                        //         this(DirEntry resultFile)
                        //         {
                        //             super(&run);
                        //             this.resultFile = resultFile;
                        //         }

                        //     private:
                        //         void run()
                        //         {
                        //             // Derived thread running.
                        //             resultCallback(buildFileInfo(this.resultFile));
                        //         }
                        //     }

                        //     auto derived = new ResultThread(currentFile).start();
                        // }
                        // catch (Exception e)
                        // {
                      
                          if(resultCallback is null) throw new Exception("resultCallback can't be null before calling the callback");
                         // Logger.logError(to!string(userObj),"RESULT CALLBACK");
                        
                        immutable(FileInfo) fi = buildFileInfo(currentFile);
                        // FileInfo* fiptr = new FileInfo();
                        // *fiptr = fi;
                        assert(userObj !is null);
                        // assert(fiptr !is null);
                        resultCallback(fi, cast(void*)userObj);
                        // }

                    }
                    else
                    {
                        Logger.logTrace("Not matching file, skipped: "~currentFile.name,this.toString());
                    }
                }
                catch (Exception e)
                {
                    Logger.logError(e.msg,this.toString());
                }
            }
        }

        this.running = false;
        Logger.logDebug("Finished its job");
    }
}