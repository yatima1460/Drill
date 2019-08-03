

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

import std.experimental.logger;

import Utils : sizeToHumanReadable, systime_to_string;
import FileInfo : FileInfo;

import std.concurrency : spawn;
import std.container.dlist : DList;



alias CrawlerCallback = void function(  const(FileInfo) result, void* userObject);




unittest
{
    assert(isFileNameMatchingSearchString(".","."));
    assert(isFileNameMatchingSearchString("a","a"));

    assert(isFileNameMatchingSearchString("aaaa","aaaaa"));
    assert(!isFileNameMatchingSearchString("aaaaa","aaaa"));

    assert(isFileNameMatchingSearchString("jojo 39","JoJo's Bizarre Adventures Golden Wind 39.mkv"));
    assert(!isFileNameMatchingSearchString("jojo 38","JoJo's Bizarre Adventures Golden Wind 39.mkv"));
    assert(isFileNameMatchingSearchString("jojo 3","JoJo's Bizarre Adventures Golden Wind 39.mkv"));
    assert(!isFileNameMatchingSearchString("jojo3","JoJo's Bizarre Adventures Golden Wind 39.mkv"));
    assert(isFileNameMatchingSearchString("jojo","JoJo's Bizarre Adventures Golden Wind 39.mkv"));
    assert(isFileNameMatchingSearchString("39","JoJo's Bizarre Adventures Golden Wind 39.mkv"));
    assert(isFileNameMatchingSearchString("olde","JoJo's Bizarre Adventures Golden Wind 39.mkv"));
    assert(isFileNameMatchingSearchString("JoJo's Bizarre Adventures Golden Wind 39.mkv","JoJo's Bizarre Adventures Golden Wind 39.mkv"));
    assert(isFileNameMatchingSearchString(".mkv","JoJo's Bizarre Adventures Golden Wind 39.mkv"));
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
bool isInRegexList(const(Regex!char[]) list, const(string) value)
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
            error(e.message);
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

unittest
{
    import std.file : thisExePath;
    FileInfo f = buildFileInfo(DirEntry(thisExePath));
    assert(f.thread == "");
    assert(!f.isDirectory);
    assert(f.isFile);
    assert(f.dateModifiedString);
    assert(canFind(f.containingFolder,"/Build/Drill-CLI-linux-x86_64-unittest-cov"));
    assert(f.fileName == "drill-search-test-CLI");
    assert(f.fileNameLower == "drill-search-test-cli");
    assert(f.extension == "");
    assert(canFind(f.fullPath,"/Build/Drill-CLI-linux-x86_64-unittest-cov/drill-search-test-CLI"),f.fullPath);
    assert(!canFind(f.sizeString, "0 B"));
}
unittest
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


/++
    Given a file and a blocklist will determine if the file should be skipped or not
+/
bool shouldSkipDirectory(DirEntry currentDirectory, const Regex!char[] blockListRegex)
in (currentDirectory.isDir())
{
    try
    {
        if (currentDirectory.isSymlink())
        {
            trace("Symlink ignored: " ~ currentDirectory.name);
            return true;
        }
    }
    catch (Exception e)
    {
        return true;
    }

    if (isInRegexList(blockListRegex, currentDirectory.name))
    {
        trace("Blacklisted: " ~ currentDirectory.name);
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
bool tryGetShallowFiles(DirEntry currentDirectory, out DirIterator iterator)
in (currentDirectory.isDir())
{
    try
    {
        //FIXME: is "true" as third argument needed here?
        // Are some folders marked as symlink when they actually aren't on Windows?
        iterator = dirEntries(currentDirectory, SpanMode.shallow, true);
        return true;
    }
    catch (Exception e)
    {   
        error(e.msg);
        return false;
    }
}





import Context : MatchingFunction;

void crawlDirectory(DirEntry currentDirectory, 
                    const Regex!char[] blockListRegex, 
                    const Regex!char[] priorityListRegex, 
                    const(string) searchString, 
                    CrawlerCallback* resultCallback, 
                    const(void*) userObject,
                    DList!DirEntry queue,
                    MatchingFunction matchingFunction,
                    shared(bool)* running)
in (currentDirectory.isDir())
{

    // // // // /*
    // // // //     NOTE:
    // // // //     A "File" in the more general term and in this function can be both a normal file and a directory
    // // // //     unless isDir() is checked
    // // // // */



    // Then if the directory was not skipped we get a list of the shallow files inside
    // NOT RECURSIVELY, JUST THE FILES IMMEDIATELY INSIDE
    // If we fail to get the files we just stop this directory scanning

    // NOTE: do not use IFs but use switches here in the hot path 
    //       so we don't have CPU branching
    DirIterator files;
    final switch (tryGetShallowFiles(currentDirectory, files))
    {
        case false:
            return;
        case true:
            break;
    }

    // If we could get the files inside we start to scan all of them
    foreach (DirEntry currentFile; files)
    {
        if (!*running) break;
        // if (shouldSkipDirectory(currentFile,blockListRegex))
        //     continue;

        try
        {
            final switch (currentFile.isSymlink())
            {
                case false:
                    break;
                case true:
                    trace("Symlink ignored: " ~ currentDirectory.name);
                    continue;
            }
            

            // If the file is a directory we check its priority and then enqueue it
            final switch (currentFile.isDir())
            {
                // The file is a directory
                case true:
                    // First we check if we can skip the directory straight away
                    // In this way the queue does not get filled <=== that's the plan
                    final switch(shouldSkipDirectory(currentFile,blockListRegex))
                    {
                        case false:
                            if (isInRegexList(priorityListRegex, currentFile.name))
                            {
                                trace("High priority: "~currentFile.name);
                                queue.insertFront(currentFile);
                            }
                            else
                            {
                                //trace("Low priority: "~currentFile.name);
                                queue.insertBack(currentFile);
                            }
                            break;
                        case true:
                            continue;
                    }
                    goto case false;

                // Switch fallthrough here, so directories are added too
                case false:

                    // TODO: function pointer as predicate for search matching

                    final switch (matchingFunction(currentFile,searchString))
                    {
                        // The file does not match the search
                        case false:
                            continue;
                        // The file name matches the search string
                        case true:
                            trace("Matching search"~currentFile.name);
                            immutable(FileInfo) fi = buildFileInfo(currentFile);
                            //assert(userObject !is null);
                            assert(resultCallback !is null,"resultCallback can't be null before calling the callback");
                            (*resultCallback)(fi, cast(void*)userObject);
                            break;
                    }
                  
            }
        }
        catch (Exception e)
        {
            critical(e.msg);
        }
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
            import core.stdc.stdio;
            printf("Crawler destroyed\n");
        }
    }

    import Context: MatchingFunction;

private:
    const(string) MOUNTPOINT;
    const(string) SEARCH_STRING;
    const(string[]) BLOCK_LIST;

    Regex!char[] BLOCK_LIST_REGEX;
    const(Regex!char[]) PRIORITY_LIST_REGEX;
    
    shared(bool) running;

    const(MatchingFunction) matchingFunction;

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
        in void* userObject,
        MatchingFunction matchingFunction
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

        info("Created",this.toString());
        info("Search term '" ~ search ~ "'",this.toString());
        info("Global blocklist.length = " ~ to!string(BLOCK_LIST.length),this.toString());

       
        info("Global priority list length = " ~ to!string(PRIORITY_LIST_REGEX.length),this.toString());
        this.PRIORITY_LIST_REGEX = PRIORITY_LIST_REGEX;

        this.SEARCH_STRING = search;
        this.resultCallback = resultCallback;
        this.BLOCK_LIST = BLOCK_LIST;


        this.running = true;

        this.userObject = userObject;
        this.matchingFunction = matchingFunction;
    }

    private void noop_resultFound(const(FileInfo) result,void* v) const
    {

    }

    void stopAsync()
    {
        infof("Crawler '%s' async stop requested",MOUNTPOINT);
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

    ^^^ Is this really true? Maybe slow RAM and CPU can slow down too much the DMA requests too?
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
        info("Adding these to the global blocklist: " ~ to!string(cp_tmp),this.toString());
        Array!string crawler_exclusion_list = Array!string(BLOCK_LIST);
        crawler_exclusion_list ~= cp_tmp;
        Regex!char[] exclusion_regexes = crawler_exclusion_list[].map!(x => regex(x,"i")).array;
        this.BLOCK_LIST_REGEX = exclusion_regexes;

        info("New crawler custom blocklist.length = " ~ to!string(BLOCK_LIST_REGEX.length),this.toString());
        info("Started");

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
            error(e.msg,this.toString());
            this.running = false;
            return;
        }

        // If the mountpoint root is ok we start to scan everything
        while (!queue.empty() && running)
        {
            // Pop a directory from the queue
            DirEntry currentDirectory = queue.front();
            queue.removeFront();

            //trace("Directory: " ~ currentDirectory.name,this.toString());
            crawlDirectory(
                currentDirectory,
                BLOCK_LIST_REGEX,
                PRIORITY_LIST_REGEX,
                SEARCH_STRING,
                &resultCallback, 
                cast(void*)userObject,
                queue, 
                matchingFunction,
                &running
            );
        }

        // If this line is reached it means the crawler finished all the entire mountpoint to scan
        this.running = false;
        info("Finished its job");
    }
}