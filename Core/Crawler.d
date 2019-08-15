


import core.thread : Thread;
import core.stdc.stdio;

import std.container : Array;
import std.stdio : writeln;
import std.file : DirEntry, DirIterator, dirEntries, SpanMode;
import std.algorithm : sort, map, filter, canFind;
import std.path : baseName, dirName, extension;
import std.array : array, replace;
import std.conv : to;
import std.uni : toLower;
import std.regex : Regex, regex, RegexMatch, match;
import std.string : split, strip;
import std.experimental.logger;
import std.string : toStringz;
import std.concurrency : spawn;
import std.container.dlist : DList;

import Utils : sizeToHumanReadable, systime_to_string, getMountpoints;
import FileInfo : FileInfo;
import MatchingFunctions : MatchingFunction;

alias CrawlerCallback = void delegate(const(FileInfo) result, void* userObject) @safe;



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
@safe bool matchesRegexList(const(Regex!char[]) list, const(string) value)
in (value != null)
{
    foreach (ref regexrule; list)
    {
        try
        {
            RegexMatch!string mo = match(value, regexrule);
            if (!mo.empty())
            {
                return true;
            }
        }
        catch(Exception e)
        {
            error(e.msg);
            continue;
        }
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
        Thread.getThis.name,
        currentFile.isDir(),
        !currentFile.isDir(),
        systime_to_string(currentFile.timeLastModified()),
        dirName(currentFile.name),
        baseName(currentFile.name),
        toLower(baseName(currentFile.name)),
        extension(currentFile.name),
        currentFile.name,
        !currentFile.isDir() ? sizeToHumanReadable(currentFile.size) : ""
    };
    return f;
}

@safe unittest
{
    import std.file : thisExePath;
    FileInfo f = buildFileInfo(DirEntry(thisExePath));
    assert(f.thread == "");
    assert(!f.isDirectory);
    assert(f.isFile);
    assert(f.dateModifiedString);
    assert(canFind(f.containingFolder,"Build"));
    assert(canFind(f.containingFolder,"unittest"));

    version (Windows)
    {
        assert(f.fileName == "drill-test-CLI.exe" || f.fileName == "drill-test-GTK.exe",f.fileName);
        assert(f.fileNameLower == "drill-test-cli.exe" || f.fileNameLower == "drill-test-gtk.exe",f.fileName);
        assert(f.extension == ".exe");
    }
    else
    {
        assert(f.fileName == "drill-test-CLI" || f.fileName == "drill-test-GTK",f.fileName);
        assert(f.fileNameLower == "drill-test-cli" || f.fileNameLower == "drill-test-gtk",f.fileName);
        assert(f.extension == "");
    }


    assert(canFind(f.fullPath, f.containingFolder));
    assert(!canFind(f.sizeString, "0 B"));
}

@safe unittest
{
    FileInfo f = buildFileInfo(DirEntry("/"));
    assert(f.thread == "");
    assert(f.isDirectory);
    assert(!f.isFile);
    assert(f.dateModifiedString);
    assert(canFind(f.containingFolder,"/"));
    assert(f.fileName == "/");
    assert(f.fileNameLower == "/");
    assert(f.extension == "");
    assert(canFind(f.fullPath,"/"),f.fullPath);
    assert(!canFind(f.sizeString, "0 B"));

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


// @safe bool shouldSkipDirectory(DirEntry currentDirectory, const Regex!char[] blockListRegex)
// in (currentDirectory.isDir() == true)
// {
//     return isInRegexList(blockListRegex,currentDirectory.name) || currentDirectory.isSymlink();
// }


// /++
//     Given a file and a blocklist will determine if the file should be skipped or not
// +/
// bool shouldSkipDirectory(DirEntry currentDirectory, const Regex!char[] blockListRegex)
// in (currentDirectory.isDir())
// {
//     try
//     {
//         if (currentDirectory.isSymlink())
//         {
//             trace("Symlink ignored: " ~ currentDirectory.name);
//             return true;
//         }
//     }
//     catch (Exception e)
//     {
//         return true;
//     }

//     if (isInRegexList(blockListRegex, currentDirectory.name))
//     {
//         trace("Blacklisted: " ~ currentDirectory.name);
//         return true;
//     }

//     return false;
// }



/++
    Returns a lazy iterator for the files immediately inside a directory

    Params:
        currentDirectory = the directory to scan
        iterator = the iterator output

    Returns:
        true if successful, false if the iterator returned is invalid

    Complexity:
        O(1)
+/
nothrow bool tryGetShallowFiles(DirEntry currentDirectory, out DirIterator iterator)
in (currentDirectory.isDir())
{
    try
    {
        // FIXME: is "true" as third argument needed here?
        // Are some folders marked as symlink when they actually aren't on Windows?
        iterator = dirEntries(currentDirectory, SpanMode.shallow, true);
        return true;
    }
    catch (Exception e)
        try
            error(e.msg);
        catch (Exception e)
            printf(toStringz(e.msg));
    return false;
}





@safe void elaborateFile(DirEntry currentFile, const Regex!char[] blockListRegex,const Regex!char[] priorityListRegex, MatchingFunction matchingFunction,  DList!DirEntry queue, string searchString, CrawlerCallback resultCallback, void* userObject)
in (resultCallback !is null)
{
    // FIXME: check the FIXME inside tryGetShallowFiles
    if (currentFile.isSymlink())
    {
        trace("Symlink ignored: " ~ currentFile.name);
        return;
    }

    /+
        If the file is a directory now
        we check its priority and then enqueue it
    +/
    if (currentFile.isDir())
    {
        if (matchesRegexList(blockListRegex, currentFile.name))
        {
            trace("File in blocklists: "~currentFile.name~" skipped.");
            return;
        }
        if (matchesRegexList(priorityListRegex, currentFile.name))
        {
            trace("High priority: " ~ currentFile.name);
            queue.insertFront(currentFile);
        }
        else
        {
            trace("Low priority: "~currentFile.name);
            queue.insertBack(currentFile);
        }
    }

        
    /+
        The file (normal file or folder) does match the search:
        we send it to the callback result function
    +/
    if (matchingFunction(currentFile, searchString))
    {
        trace("Matching search" ~ currentFile.name);
        immutable(FileInfo) fi = buildFileInfo(currentFile);
        
      
        if (resultCallback is null)
        {
           
            throw new Exception(
                    "resultCallback can't be null before calling the callback");

        }
        
        
        resultCallback(fi,  userObject);
       
    }
}


void crawlDirectory(DirEntry currentDirectory, 
                    const Regex!char[] blockListRegex, 
                    const Regex!char[] priorityListRegex, 
                    const(string) searchString, 
                    CrawlerCallback resultCallback, 
                    void* userObject,
                    DList!DirEntry queue,
                    MatchingFunction matchingFunction,
                    shared(bool)* running)
in (currentDirectory.isDir())
in (searchString !is null)
in (searchString.length > 0)
in (resultCallback !is null)
in (matchingFunction !is null)
in (running !is null)
{
    /+
        NOTE:
        A "File" in the more general term and in this function can be 
        both a normal file and a directory unless isDir() is checked
    +/

    /+
        README!!!
        If we reach this point the directory we are scanning is already confirmed
        to be scanned, a directory should be confirmed BEFORE adding it to the queue,
        so the queue doesn't get saturated of useless directories that will be excluded later
    +/

    /+
        README!!!
        only directories should be checked against blocklists
        files will slow down and it's useless to scan them,
        who cares if a user will see an useless file,
        but we care because they slow down the Drill crawling
    +/

    /+
        We get a list of the shallow files inside
        NOT RECURSIVELY, JUST THE FILES IMMEDIATELY INSIDE
        If we fail to get the files we just stop this directory scanning
    +/
    DirIterator files;
    if (!tryGetShallowFiles(currentDirectory, files))
    {
        error("Trying to get shallow files of "~currentDirectory~" failed.");
        return;
    }

    /+ 
        NOTE: the DirIterator is "lazy" and only evaluates its data when it's encountered
        in a foreach loop, so it could crash; this is why there is this try-catch
    +/
    try 
    {
        foreach (DirEntry currentFile; files)
        {
            assert(running !is null);
            if (*running == false)
            {
                trace("Breaking file loop because 'running' is now false");
                break;
            }
                

            try
            {
                elaborateFile(currentFile,blockListRegex,priorityListRegex, matchingFunction, queue, searchString, resultCallback, userObject);
            }
            catch (Exception e)
            {
                critical(e.msg);
            }
        }
    }
    catch (Exception e)
    {
        critical(currentDirectory.name," ",e.msg);
    }
}




// auto composed = new Thread(&threadFunc).start();
// TODO: remove this OOP hell
class Crawler : Thread
{

    debug
    {
        ~this()
        {
            

            import core.stdc.stdio : printf;
            printf("Crawler destroyed\n");
        }
    }

import core.sync.barrier : Barrier;

private:
    const(string) MOUNTPOINT;
    invariant
    {
        assert(MOUNTPOINT !is null);
        assert(MOUNTPOINT.length > 0);

    }

    const(string) SEARCH_STRING;
    invariant
    {
        assert(SEARCH_STRING !is null);
        assert(SEARCH_STRING.length > 0);

    }
 
    Regex!char[] BLOCK_LIST_REGEX;
    invariant
    {
        assert(BLOCK_LIST_REGEX.length > 0);
    }

    const(Regex!char[]) PRIORITY_LIST_REGEX;
    invariant
    {
        assert(PRIORITY_LIST_REGEX.length > 0);
    }
    
    shared(bool) shouldCrawl;

    const(MatchingFunction) matchingFunction;
    invariant
    {
        assert(matchingFunction !is null);
    }

    CrawlerCallback resultCallback;
    

    bool crawling;

    Barrier barrier;
    invariant
    {
        assert(barrier !is null);
    }

    debug
    {
        long ignored_count;
    }

       const(void*) userObject;


public:

    @safe this(
        const(string) MOUNTPOINT, 
        Regex!char[] BLOCK_LIST,
        const(Regex!char[]) PRIORITY_LIST_REGEX,
        in CrawlerCallback resultCallback, 
        in immutable(string) search,
        in void* userObject,
        MatchingFunction matchingFunction,
        Barrier barrier
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

        trace("Created", MOUNTPOINT);
        trace("Search term '" ~ search ~ "'",MOUNTPOINT);
        trace("Global blocklist.length = " ~ to!string(BLOCK_LIST.length),MOUNTPOINT);

       
        trace("Global priority list length = " ~ to!string(PRIORITY_LIST_REGEX.length),MOUNTPOINT);
        this.PRIORITY_LIST_REGEX = PRIORITY_LIST_REGEX;

        this.SEARCH_STRING = search;
        this.resultCallback = resultCallback;
        this.BLOCK_LIST_REGEX = BLOCK_LIST;


        this.shouldCrawl = true;

        this.userObject = userObject;
        this.matchingFunction = matchingFunction;
        this.barrier = barrier;
    }

    @safe void stopAsync()
    {
        infof("Crawler '%s' async stop requested", MOUNTPOINT);
        this.resultCallback = null;
        this.shouldCrawl = false;
    }

    pure const @safe override string toString()
    {
        return "Crawler(" ~ MOUNTPOINT ~ ")";
    }

    pure nothrow const @safe @nogc bool isCrawling()
    {
        return this.crawling;
    }


    /**
    NOTE: We don't really care about CPU time, Drill isn't CPU intensive but disk intensive,
    in this function it's not bad design that there are multiple IFs checking the same thing over and over again,
    but it's done to stop the crawling as soon as possible to have more time to crawl important files.

    ^^^ Is this really true? Maybe slow RAM and CPU can slow down too much the DMA requests too?
    */
    void run()
    in (SEARCH_STRING != null, "the search string can't be null")
    in (SEARCH_STRING.length != 0,"the search string can't be empty")
    // in (running == false, "the crawler is marked running when it isn't even run yet")
    in (MOUNTPOINT  != null, "the mountpoint can't be null")
    in (MOUNTPOINT.length != 0, "the mountpoint string can't be empty")
    in (resultCallback != null, "the result callback can't be null")
    {
        crawling = true;
        infof("Crawler %s waiting on the barrier", MOUNTPOINT);
        barrier.wait();


        if (shouldCrawl == false)
        {
            crawling = false;
           
            
            return;
        }
           
       
    
        infof("Crawler '%s' started", MOUNTPOINT);

        /+
            Every Crawler will have all the other mountpoints in its blocklist
            In this way crawlers will not cross paths in the worst case scenario
        +/
        auto mountpointsMinusCurrentOne = getMountpoints()[].filter!(x => x != MOUNTPOINT).map!(x => "^" ~ x ~ "$");
        this.BLOCK_LIST_REGEX ~= mountpointsMinusCurrentOne.map!(x => regex(x,"i")).array;

        // Use the queue as a stack to scan using a breadth-first algorithm
        DList!DirEntry queue;

        /+
            Try to insert the mountpoint in the queue as first element
            It could fail for permission or I/O reasons,
            and if it does we just terminate the crawler instantly
        +/
        try
        {
            queue.insertBack(DirEntry(MOUNTPOINT));
        }
        catch (Exception e)
        {
            errorf("Trying to start crawler at mountpoint: '%s' failed with error: '%s'",MOUNTPOINT,e.msg);
            this.shouldCrawl = false;
            this.crawling = false;
            
            
            return;
        }


        

       

        // If the mountpoint root is ok we start to scan everything
        while (!queue.empty() && shouldCrawl)
        {
            // Pop a directory from the queue
            DirEntry currentDirectory = queue.front();
            assert(currentDirectory.isDir());
            assert(!matchesRegexList(this.BLOCK_LIST_REGEX, currentDirectory.name));
            queue.removeFront();

            crawlDirectory(
                currentDirectory,
                BLOCK_LIST_REGEX,
                PRIORITY_LIST_REGEX,
                SEARCH_STRING,
                resultCallback, 
                cast(void*)userObject,
                queue, 
                matchingFunction,
                &shouldCrawl
            );
        }

        scope(exit) 
        {

        crawling = false;

        // If this line is reached it means the crawler finished all the entire mountpoint to scan
        this.shouldCrawl = false;
         infof("Crawler '%s' finished its job", MOUNTPOINT);
        }
      
    }
}
