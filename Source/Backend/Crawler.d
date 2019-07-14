module Crawler;

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
import Utils : humanSize, toDateString;
import FileInfo : FileInfo;
import API : DrillAPI;

import std.functional : memoize;
alias memoizedDirEntries = memoize!dirEntries;

DirEntry _memoizedDirEntry(immutable(string) fullPath)
{
    return DirEntry(fullPath);
}

alias memoizedDirEntry = memoize!_memoizedDirEntry;

class Crawler : Thread
{

private:
    immutable(string) MOUNTPOINT;
    immutable(string) SEARCH_STRING;
    immutable(string[]) BLOCK_LIST;

    Regex!char[] BLOCK_LIST_REGEX;
    const(Regex!char[]) PRIORITY_LIST_REGEX;
    
    shared(bool) running;

    void function(  immutable(FileInfo) result, void* userObject) resultCallback;

    debug
    {
        long ignored_count;
    }

      void* userObj;


public:

    this(
        immutable(string) MOUNTPOINT, 
        immutable(string[]) BLOCK_LIST,
        const(Regex!char[]) PRIORITY_LIST_REGEX,
        void function(immutable(FileInfo) result, void* userObject) resultCallback, 
        immutable(string) search,
        void* userObj
    )
    in (MOUNTPOINT != null)
    in (MOUNTPOINT.length != 0)
    in (resultCallback != null)
    in (search != null)
    in (search.length != 0)
    {
        assert(userObj !is null, "it does not make sense for a userObject to be null");
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


        

        this.userObj = userObj;
    }

    private void noop_resultFound(immutable(FileInfo) result,void*) @nogc const pure @safe
    {

    }

    pure void stopAsync() @nogc
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

    bool isInRegexList(const(Regex!char[]) list, immutable(string) value) const @safe
    in (value != null)
    {
        foreach (ref regexrule; list)
        {
            if (!this.running) return false;
            RegexMatch!string mo = match(value, regexrule);
            if (!mo.empty())
                return true;
        }
        return false;
    }

    immutable(FileInfo) buildFileInfo(DirEntry currentFile) const
    {
        FileInfo f;
        f.isDirectory = !currentFile.isDir();
        f.isDirectory = currentFile.isDir();
        f.fullPath = currentFile.name;
        f.fileName = baseName(currentFile.name);
        f.fileNameLower = toLower(f.fileName);
        f.containingFolder = dirName(currentFile.name);
        f.extension = extension(currentFile.name);
        f.sizeString = humanSize(currentFile.size);
        f.originalMountpoint = this.MOUNTPOINT;
        f.dateModifiedString = toDateString(currentFile.timeLastModified());
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

    public:

    /**
    NOTE: We don't really care about CPU time, Drill isn't CPU intensive but disk intensive,
    in this function it's not bad design that there are multiple IFs checking the same thing over and over again,
    but it's done to stop the crawling as soon as possible to have more time to crawl important files.
    */
    void run()
    {
        assert(SEARCH_STRING != null, "the search string can't be null");
        assert(SEARCH_STRING.length != 0,"the search string can't be empty");
        assert(this.running == false, "the crawler is marked running when it isn't even run yet");
        assert(MOUNTPOINT  != null, "the mountpoint can't be null");
        assert(MOUNTPOINT.length != 0, "the mountpoint string can't be empty");
        assert(resultCallback != null, "the result callback can't be null");

         // Every Crawler will have all the other mountpoints in its blocklist
        // In this way crawlers will not cross paths
        string[] cp_tmp = DrillAPI.getMountPoints()[].filter!(x => x != MOUNTPOINT)
            .map!(x => "^" ~ x ~ "$")
            .array;
        Logger.logDebug("Adding these to the global blocklist: " ~ to!string(cp_tmp),this.toString());
        Array!string crawler_exclusion_list = Array!string(BLOCK_LIST);
        crawler_exclusion_list ~= cp_tmp;
        Regex!char[] exclusion_regexes = crawler_exclusion_list[].map!(x => regex(x)).array;
        this.BLOCK_LIST_REGEX = exclusion_regexes;

        Logger.logDebug("New crawler custom blocklist.length = " ~ to!string(BLOCK_LIST_REGEX.length),this.toString());

        this.running = true;
        Logger.logDebug("Started");

        import std.container.dlist : DList;
        DList!DirEntry queue;
        if (isInRegexList(BLOCK_LIST_REGEX,MOUNTPOINT))
        {
            this.running = false;
            Logger.logDebug("Crawler mountpoint is in the blocklist, the crawler will stop.",this.toString());
        }
        else
        {
            try
            {
                queue.insertBack(memoizedDirEntry(MOUNTPOINT));
            }
            catch (Exception e)
            {
                Logger.logError(e.msg,this.toString());
                this.running = false;
            }
        }

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
                files = memoizedDirEntries(currentDirectory, SpanMode.shallow, true);
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
                    if (!this.running) return;
                    if (isInRegexList(BLOCK_LIST_REGEX, currentFile.name))
                    {
                        //Logger.logDebug("Ignored: " ~ currentFile.name,this.toString());
                        continue;
                    }
                    if (!this.running) return;
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
                    if (!this.running) return;
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
                          if(userObj is null) throw new Exception("userObj can't be null before calling the callback");
                          if(resultCallback is null) throw new Exception("resultCallback can't be null before calling the callback");
                         // Logger.logError(to!string(userObj),"RESULT CALLBACK");
                        
                        immutable(FileInfo) fi = buildFileInfo(currentFile);
                        resultCallback(fi, userObj);
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