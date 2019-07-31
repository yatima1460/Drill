

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
import std.container.dlist : DList;


alias CrawlerCallback = void function(  const(FileInfo) result, void* userObject);



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
nothrow @safe bool isInRegexList(const(Regex!char[]) list, const(string) value)
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



nothrow @safe bool isPriorityDirectory(DirEntry currentFile, const(Regex!char[]) priorityListRegex)
in (currentFile.isDir())
{
    return isInRegexList(priorityListRegex, currentFile.name);
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


/++
    Given a file and a blocklist will determine if the file should be skipped or not
+/
nothrow @safe bool shouldSkipFile(DirEntry currentFile, const Regex!char[] blockListRegex)
{
    try
    {
        if (currentFile.isSymlink())
        {
            Logger.logTrace("Symlink ignored: " ~ currentFile.name);
            return true;
        }
    }
    catch (Exception e)
    {
        return true;
    }

    if (isInRegexList(blockListRegex, currentFile.name))
    {
        Logger.logTrace("Ignored: " ~ currentFile.name);
        return true;
    }

    return false;
}


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
        iterator = dirEntries(currentDirectory, SpanMode.shallow, true);
        return true;
    }
    catch (Exception e)
    {   
        Logger.logError(e.msg);
        return false;
    }
}



void crawlDirectory(DirEntry currentDirectory, 
                    const Regex!char[] blockListRegex, 
                    const Regex!char[] priorityListRegex, 
                    const(string) searchString, 
                    CrawlerCallback* resultCallback, 
                    const(void*) userObject,
                    DList!DirEntry queue)
in (currentDirectory.isDir())
{
    /*
        NOTE:
        A "File" in the more general term and in this function can be both a normal file and a directory
        unless isDir() is checked
    */

    // First we check if we can skip the directory straight away
    if (shouldSkipFile(currentDirectory,blockListRegex))
        return;

    // Then if the directory was not skipped we get a list of the shallow files inside
    // NOT RECURSIVELY, JUST THE FILES IMMEDIATELY INSIDE
    // If we fail to get the files we just stop this directory scanning
    DirIterator files;
    if (!tryGetShallowFiles(currentDirectory, files))
        return;

    // If we could get the files inside we start to scan all of them
    foreach (DirEntry currentFile; files)
    {
        if (shouldSkipFile(currentFile,blockListRegex))
            continue;

        try
        {
            // TODO: remove this IF branch using a lookup table

            // If the file is a directory we check its priority and then enqueue it
            if (currentFile.isDir())
            {
                // TODO: remove this IF branch using a lookup table
                if (isPriorityDirectory(currentFile, priorityListRegex))
                {
                    Logger.logTrace("High priority: "~currentFile.name);
                    queue.insertFront(currentFile);
                }
                else
                {
                    Logger.logTrace("Low priority: "~currentFile.name);
                    queue.insertBack(currentFile);
                }
            }
            
            // If the file matches the search we consider it a result
            // we don't care if it's a normal file or a directory
            if (isFileNameMatchingSearchString(searchString, currentFile.name))
            {
                Logger.logTrace("Matching search"~currentFile.name);
              
                immutable(FileInfo) fi = buildFileInfo(currentFile);
                assert(userObject !is null);
                assert(resultCallback !is null,"resultCallback can't be null before calling the callback");
                (*resultCallback)(fi, cast(void*)userObject);
            }
            else
            {
                Logger.logTrace("Not matching file, skipped: "~currentFile.name);
            }
        }
        catch (Exception e)
        {
            Logger.logError(e.msg);
        }
    }
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

    CrawlerCallback resultCallback;

    debug
    {
        long ignored_count;
    }

       const(void*) userObject;


public:

    this(
        in const(string) MOUNTPOINT, 
        in const(string[]) BLOCK_LIST,
        in const(Regex!char[]) PRIORITY_LIST_REGEX,
        in CrawlerCallback resultCallback, 
        in immutable(string) search,
        in void* userObject
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

        this.userObject = userObject;
    }

    private void noop_resultFound(const(FileInfo) result,void* v) const
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

    pure nothrow const @safe @nogc bool isCrawling()
    {
        return this.running;
    }

    /**
    NOTE: We don't really care about CPU time, Drill isn't CPU intensive but disk intensive,
    in this function it's not bad design that there are multiple IFs checking the same thing over and over again,
    but it's done to stop the crawling as soon as possible to have more time to crawl important files.
    */
    void run()
    {
        if (running == false)
            return;
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

        // Use the queue as a stack to scan using a breadth-first algorithm
        DList!DirEntry queue;

        // Try to insert the mountpoint in the queue as first element
        // It could fail for permission or I/O reasons,
        // and if it does we just terminate the crawler instantly
        try
        {
            queue.insertBack(DirEntry(MOUNTPOINT));
        }
        catch (Exception e)
        {
            Logger.logError(e.msg,this.toString());
            this.running = false;
            return;
        }

        // If the mountpoint root is ok we start to scan everything
        while (!queue.empty() && running)
        {
            // Pop a directory from the queue
            DirEntry currentDirectory = queue.front();
            queue.removeFront();

            Logger.logTrace("Directory: " ~ currentDirectory.name,this.toString());
            crawlDirectory(currentDirectory,BLOCK_LIST_REGEX,PRIORITY_LIST_REGEX,SEARCH_STRING,&resultCallback, cast(void*)userObject,queue);
        }

        // If this line is reached it means the crawler finished all the entire mountpoint to scan
        this.running = false;
        Logger.logDebug("Finished its job");
    }
}