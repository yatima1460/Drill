

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

import std.concurrency : spawn;



alias CrawlerCallback = void function(  immutable(FileInfo) result, void* userObject);



/++
    Params:
        searchString = the search string the user wrote in a Drill frontend
        fileName = the complete file name without a fullpath, only the file name after the slash

    Returns:
        true if the file matches the search input

    Complexity:
        O(searchString*fileName)
+/
pure @safe bool isFileNameMatchingSearchString(const(string) searchString, const(string) fileName) 
in (searchString != null)
in (searchString.length > 0)
in (fileName != null)
in (fileName.length > 0)
{
    if (fileName.length < searchString.length) return false;
    const string[] searchTokens = toLower(strip(searchString)).split(" ");
    const string fileNameLower = toLower(baseName(fileName));
    foreach (token; searchTokens)
        if (!canFind(fileNameLower, token))
            return false;
    return true;
}

/++
    Check if the value is inside a regex list

    Params:
        list = compiled Regex list
        value = value to search inside

    Returns:
        true if the value matches at least one Regex rule

    Complexity:
        O(list)
+/
@safe bool _isInRegexList(const(Regex!char[]) list, const(string) value)
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

/++
    Builds a fileinfo struct given a DirEntry as input

    Params:
        currentFile = the file to convert to the Drill FileInfo format

    Returns:
        the struct FileInfo with more human readable data inside about the file

    Complexity:
        O(currentFile.name)
+/
@safe FileInfo buildFileInfo(DirEntry currentFile)
{
    FileInfo f = {
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


// struct CrawlerData
// {
//     string root;
//     string searchString;
//     string[] blockList;

//     Regex!char[] blockListRegex;
//     Regex!char[] priorityListRegex;

//     CrawlerCallback resultCallback;

//     Variant userObject;
// }


// struct CrawlerContext
// {
//     Tid thread;
//     bool running;

// }

// import  std.concurrency;





// ref CrawlerContext startCrawler(CrawlerData data)
// in(data.resultCallback !is null)
// out(c;c.running)
// {
//     CrawlerContext* c = new CrawlerContext();
//     c.thread = spawn(&crawl, cast(immutable)data, cast(shared)c),
//     c.running = true;
//     return c;
// }












// static void crawl(Tid ownerTid)//immutable(CrawlerData) data, shared CrawlerContext context)
// {


//     receive((int i){
//         //auto received = text("Received the number ", i);

//         // Send a message back to the owner thread
//         // indicating success.
//         send(ownerTid, true);
//     });
    
// }


// Tid startCrawler()
// {


//     auto childTid = spawn(&crawl, thisTid);

//     send(childTid, 42);

//     return childTid;
// }



//////////////////



void crawlDirectory(DirEntry directory)
{
    
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
        string[] cp_tmp = getMountpoints()[].filter!(x => x != MOUNTPOINT).map!(x => "^" ~ x ~ "$").array;
        Logger.logDebug("Adding these to the global blocklist: " ~ to!string(cp_tmp),this.toString());
        Array!string crawler_exclusion_list = Array!string(BLOCK_LIST);
        crawler_exclusion_list ~= cp_tmp;
        Regex!char[] exclusion_regexes = crawler_exclusion_list[].map!(x => regex(x)).array;
        this.BLOCK_LIST_REGEX = exclusion_regexes;

        Logger.logDebug("New crawler custom blocklist.length = " ~ to!string(BLOCK_LIST_REGEX.length),this.toString());
        Logger.logDebug("Started");

        import std.container.dlist : DList;
        DList!DirEntry queue;

        try
        {
            queue.insertBack(DirEntry(MOUNTPOINT));
        }
        catch (Exception e)
        {
            Logger.logError(e.msg,this.toString());
            this.running = false;
        }


        while (!queue.empty() && running)
        {
            DirEntry currentDirectory = queue.front();
            queue.removeFront();



            Logger.logTrace("Directory: " ~ currentDirectory.name,this.toString());


            if (isInRegexList(BLOCK_LIST_REGEX,currentDirectory.name) || currentDirectory.isSymlink())
            {
                Logger.logTrace("Blocked: " ~ currentDirectory.name,this.toString());
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
                    
                    if (isFileNameMatchingSearchString(SEARCH_STRING, currentFile.name))
                    {
                        Logger.logTrace("Matching search"~currentFile.name,this.toString());
                        if(resultCallback is null) throw new Exception("resultCallback can't be null before calling the callback");

                        immutable(FileInfo) fi = buildFileInfo(currentFile);

                        assert(userObj !is null);
                        resultCallback(fi, cast(void*)userObj);
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