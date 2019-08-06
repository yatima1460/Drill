import Config : DrillConfig;
import FileInfo : FileInfo;
import std.variant : Variant;
import Crawler : Crawler;
import std.experimental.logger;

/++
    This struct represents an active Drill search, 
    it holds a pool of crawlers and the current state, 
    like the searched value
+/
pure nothrow @nogc struct DrillContext
{

    /++
        The value to search in the crawling, will be checked as lowercase against lowercase filenames
    +/
    string searchValue;
    invariant 
    { 
        assert(searchValue !is null, "Search value has become null in DrillContext"); 
        assert(searchValue.length > 0, "Search value has 0 length in DrillContext");
    }
    
    /++
        A list of crawlers
    +/
    Crawler[] threads;
    invariant
    {
        assert(threads.length >= 0 && threads.length <= getMountpoints().length, "Crawlers length is over mountpoints length");
    }

    /++
        Optional userObject to pass to the resultCallback
    +/
    void* userObject;
}


/++
    A crawler is active when it's scanning something.
    If a crawler cleanly finished its job it's not considered active anymore.
    If a crawler crashes (should never happen, generally only for permission problems) it's not considered active.
    Minimum: 0
    Maximum: length of total number of mountpoints unless the user started the crawlers manually

    Returns: number of crawlers active
+/
pure nothrow @safe @nogc immutable(uint) activeCrawlersCount(const Crawler[] crawlers) 
{
    int active = 0;
    foreach (thread; crawlers)
        active += thread.isCrawling();
    return active;
}


/++
    Notifies the crawlers to stop and clears the crawlers array stored inside DrillContext
    This function is non-blocking.
    If no crawling is currently underway this function will do nothing.
+/
@system void stopCrawlingAsync(ref Crawler[] crawlers)
{
    info("Requested to stop all crawlers asynchronously");
    import Crawler : Crawler; 
    foreach (Crawler crawler; crawlers)
        crawler.stopAsync();
    crawlers = []; 
    // FIXME: if nothing has a reference to a thread does the thread get GC-ed?
}


/++
    This function will return only when all crawlers finished their jobs or were stopped
    This function does not stop the crawlers!!!
+/
@system void waitForCrawlers(ref Crawler[] crawlers)
{
    import Crawler : Crawler; 
    
    import std.conv: to;
    info("Waiting for "~to!string(activeCrawlersCount(crawlers))~" crawlers to stop");
    foreach (Crawler crawler; crawlers)
    {
        info("Waiting for crawler "~to!string(crawler)~" to stop");
        import core.thread : ThreadException;
        try
        {
            //FIXME: if for whatever reason the crawler is not started this will SEGFAULT
            crawler.join();     
            info("Crawler "~to!string(crawler)~" stopped");
            crawler.destroy();
        }
        catch(ThreadException e)
        {
            critical("Thread "~crawler.toString()~" crashed when joining");
            critical(e.msg);
        }
        
    }
    info("All crawlers stopped.");

    crawlers = [];
}

import Config : loadMime;
string[string] mime;

bool isFileContentMatchingSearchString(DirEntry file, const(string) searchString)
{
    if (mime == null) mime = loadMime();
   // immutable(string[]) blacklistedExtensions = [".png",".jpg",".mp4",".psd",".lnk",".sai",".exe",".pdf",".mkv",".swf",".msi",".zip"];
    import std.file : dirEntries, SpanMode, DirEntry, readText, FileException;

    import std.array : replace;
    try
    {
    

       
        //if (allowedExtensions.canFind(extension(file.name)))
        if (!file.isDir() 
            // && file.size < 100*1024*1024 // 100 megabyte,
            && (
                extension(file.name) == ".md" // markdown is not in the RFC standard
                || mime.get(extension(file.name).replace(".",""),"").canFind("text")
            )
           // && !blacklistedExtensions.canFind(extension(file.name))
        ) 
        {
            bool found = false;
            try
            {
                string fileRead = readText!string(file);
                auto fileContent = toLower(fileRead);
                found = fileContent.canFind(toLower(searchString));
            }
            catch(Exception e)
            {
                try
                {
                    wstring fileRead = readText!wstring(file);
                    auto fileContent = toLower(fileRead);
                    found = fileContent.canFind(toLower(searchString));
                }
                catch(Exception e)
                {
                     try
                    {
                        dstring fileRead = readText!dstring(file);
                        auto fileContent = toLower(fileRead);
                        found = fileContent.canFind(toLower(searchString));
                    }
                    catch(Exception e)
                    {
                        warning(e.message);
                        return false;
                    }
                    return false;
                }
               

            }


            import core.stdc.stdlib : free;
            import core.memory : GC;
            GC.collect();
            return found;
        }
        return false;
    }
    catch (Exception e)
    {
        critical("Can't find string: '",searchString,"' inside: '",file.name,"', error is: '",e.message,"'");
        return false;
    }
    
}

/++
This function stops all the crawlers and will return only when all of them are stopped
+/
@system void stopCrawlingSync(ref Crawler[] crawlers)
{
    import Crawler : Crawler; 
    foreach (Crawler crawler; crawlers)
        crawler.stopAsync();
    waitForCrawlers(crawlers);
    info("all crawlers stopped");
}
import std.file : DirEntry;

alias MatchingFunction = bool function(DirEntry file, const(string) searchString);

import std.uni : toLower;
import std.algorithm : canFind;
import std.path : baseName, dirName, extension;
import std.string : split, strip;

pure @safe bool isTokenizedStringMatchingString(const(string) searchString, const(string) str)
{
    if (str.length < searchString.length) return false;
    const string[] searchTokens = toLower(strip(searchString)).split(" ");
    const string fileNameLower = toLower(baseName(str));
    foreach (token; searchTokens)
        if (!canFind(fileNameLower, token))
            return false;
    return true;
}

/++
    Params:
        searchString = the search string the user wrote in a Drill frontend
        fileName = the complete file name without a fullpath, only the file name after the slash

    Returns:
        true if the file matches the search input

    Complexity:
        O(searchString*fileName)
+/
pure @safe bool isFileNameMatchingSearchString(DirEntry file, const(string) searchString) 
in (searchString != null)
in (searchString.length > 0)
in (file.name != null)
in (file.name.length > 0)
{
    return isTokenizedStringMatchingString(searchString, baseName(file.name));
}




import Utils : getMountpoints;
import Crawler : CrawlerCallback;
import core.stdc.stdio : printf;

        //printf("startCrawling foreach loop userObject:%p\n",userObject);
import Crawler : matchesRegexList;
import std.algorithm : sort, map, filter, canFind;
import std.array : array;
import std.regex : Regex, regex, RegexMatch, match;
/++
Starts the crawling, every crawler will filter on its own.
Use the resultFound callback as an event to know when a crawler finds a new result.

Params:
    search = the search string, case insensitive, every word (split by space) will be searched in the file name
    resultFound = the delegate that will be called when a crawler will find a new result
+/

DrillContext startCrawling(const(DrillConfig) config, immutable(string) searchValue, const(CrawlerCallback) resultCallback, const(void*) userObject)
in (searchValue !is null, "the search string can't be null")
in (searchValue.length > 0, "the search string can't be empty")
in (resultCallback !is null, "the search callback can't be null")
{
    DrillContext c;

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
    
    c.userObject = cast(void*)userObject;

    if (c.userObject == null)
        warning("user_object is null");

    // i = case insensitive
    auto blocklistRegex = config.BLOCK_LIST.map!(x => regex(x,"i")).array;

    //getMountpoints.map!(x => !matchesRegexList(blocklistRegex,mountpoint))
    foreach (immutable(string) mountpoint; getMountpoints())
    {
        if (matchesRegexList(blocklistRegex, mountpoint))
        {
            info("Crawler mountpoint is in the blocklist, the crawler will stop.",mountpoint);
            continue;
        }
        Crawler crawler = new Crawler(mountpoint, blocklistRegex, config.PRIORITY_LIST_REGEX, resultCallback, c.searchValue, c.userObject, matchingFunction);
        crawler.isDaemon(false);
        crawler.name = mountpoint;
        if (config.singlethread)
            crawler.run();
        else
            crawler.start();
        c.threads ~= crawler;
    }
    return c;
}
