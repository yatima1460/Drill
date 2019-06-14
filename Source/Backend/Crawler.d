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

class Crawler : Thread
{

private:
    immutable(string) MOUNTPOINT;
    bool running;
    const(Regex!char[]) BLOCK_LIST_REGEX;
    const(Regex!char[]) PRIORITY_LIST_REGEX;
    void delegate(immutable(FileInfo) result) resultCallback;
    immutable(string) search;
    debug
    {
        long ignored_count;
    }


public:

    this(immutable(string) MOUNTPOINT, immutable(string[]) BLOCK_LIST,
            const(Regex!char[]) PRIORITY_LIST_REGEX,
            void delegate(immutable(FileInfo) result) resultFound, immutable(string) search)
    {

        //TODO: invariant root contains /

        super(&run);
        this.MOUNTPOINT = MOUNTPOINT;

        Logger.logDebug("Created",this.toString());
        Logger.logDebug("Search term '" ~ search ~ "'",this.toString());
        Logger.logDebug("Global blocklist.length = " ~ to!string(BLOCK_LIST.length),this.toString());

        // Every Crawler will have all the other mountpoints in its blocklist
        // In this way crawlers will not cross paths
        string[] cp_tmp = DrillAPI.getMountPoints()[].filter!(x => x != MOUNTPOINT)
            .map!(x => "^" ~ x ~ "$")
            .array;
        Logger.logDebug("Adding these to the global blocklist: " ~ to!string(cp_tmp),this.toString());
        Array!string crawler_exclusion_list = Array!string(BLOCK_LIST);
        crawler_exclusion_list ~= cp_tmp;
        const(Regex!char[]) exclusion_regexes = crawler_exclusion_list[].map!(x => regex(x)).array;
        this.BLOCK_LIST_REGEX = exclusion_regexes;

        Logger.logDebug("New crawler custom blocklist.length = " ~ to!string(BLOCK_LIST_REGEX.length),this.toString());
        Logger.logDebug("Global priority list length = " ~ to!string(PRIORITY_LIST_REGEX.length),this.toString());
        this.PRIORITY_LIST_REGEX = PRIORITY_LIST_REGEX;

        this.search = search;
        resultCallback = resultFound;
    }

    private void noop_resultFound(immutable(FileInfo) result) @nogc 
    {

    }

    pure void stopAsync() @safe @nogc
    {
        this.resultCallback = &this.noop_resultFound;
        this.running = false;
    }

    void stopSync()
    {
        this.stopAsync();
        this.join();
    }

    pure const override string toString() @safe
    {
        return "Crawler(" ~ MOUNTPOINT ~ ")";
    }

    pure const bool isCrawling() @safe @nogc
    {
        return this.running;
    }

private:

    bool isPrioritylisted(immutable(string) value)
    {
        foreach (ref regexrule; this.PRIORITY_LIST_REGEX)
        {
            RegexMatch!string mo1 = match(value, regexrule);
            if (!mo1.empty())
                return true;
        }
        return false;
    }

    bool isBlocklisted(immutable(string) value)
    {
        foreach (ref regexrule; this.BLOCK_LIST_REGEX)
        {
            // matchAll() returns a range that can be iterated
            // to get all subsequent matches.
            
            RegexMatch!string mo = match(value, regexrule);

            if (!mo.empty())
            {
                
                Logger.logTrace("Blocked, in the blocklists: '" ~ value ~ "'");
                
                debug
                {
                    this.ignored_count++;
                }
                return true;
            }
        }
        
        Logger.logTrace("Allowed, not in the blocklist: '" ~ value ~ "'",this.toString());
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


    bool isMatchingSearch(string filename)
    {
        
        const string[] searchTokens = toLower(strip(search)).split(" ");
        //writeln(searchTokens, fileNameLower);

        const string fileNameLower = toLower(baseName(filename));
        foreach (token; searchTokens)
        {
            if (!canFind(fileNameLower, token))
            {
                Logger.logTrace("Not matching search, skipped: "~fileNameLower,this.toString());
                return false;
            }
            else
            {
                Logger.logTrace("Matching search"~fileNameLower,this.toString());
            }
        }
        return true;
    }

    /**
    NOTE: We don't really care about CPU time, Drill isn't CPU intensive but disk intensive,
    in this function it's not bad design that there are multiple IFs checking the same thing over and over again,
    but it's done to stop the crawling as soon as possible to have more time to crawl important files.
    */
    void run()
    {
        this.running = true;
        Logger.logDebug("Started");

        import std.container.dlist : DList;
        DList!DirEntry queue;
        if (isBlocklisted(MOUNTPOINT))
        {
            this.running = false;
            Logger.logDebug("Crawler mountpoint is in the blocklist, the crawler will stop.",this.toString());
        }
        else
        {
            try
            {
                queue.insertBack(DirEntry(MOUNTPOINT));
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
            Logger.logDebug("Directory: " ~ currentDirectory.name,this.toString());


            if (isBlocklisted(currentDirectory.name))
            {
                Logger.logDebug("Blocked: " ~ currentDirectory.name,this.toString());
                continue;
            }

            if (currentDirectory.isSymlink())
            {
                Logger.logDebug("Symlink ignored: " ~ currentDirectory.name,this.toString());
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

            fileloop: foreach (currentFile; files)
            {
                if (!this.running) return;
                try
                {
                    if (currentFile.isSymlink())
                    {
                        Logger.logDebug("Symlink ignored: " ~ currentDirectory.name,this.toString());
                        continue fileloop;
                    }
                    if (isBlocklisted(currentFile.name))
                    {
                        Logger.logDebug("Ignored: " ~ currentFile.name,this.toString());
                        continue fileloop;
                    }
                    if (currentFile.isDir())
                    {
                        if (isPrioritylisted(currentFile.name))
                        {
                            Logger.logDebug("High priority: "~currentFile.name,this.toString());


                            // DirIterator files_priority;
                            // try
                            // {
                            //     files_priority = dirEntries(currentFile, SpanMode.shallow, true);
                            // }
                            // catch (Exception e)
                            // {
                            //     Logger.logError(e.msg,this.toString());
                            // }
                            // foreach (currentFilePriority; files_priority)
                            // {
                            //     if (!currentFilePriority.isDir())
                            //     {
                            //         if(isMatchingSearch(currentFilePriority.))
                            //     }
                            // }

                            queue.insertFront(currentFile);
                        }
                        else
                        {
                            Logger.logDebug("Low priority: "~currentFile.name,this.toString());
                            queue.insertBack(currentFile);
                        }
                    }

                                //FIXME: filter and remove empty strings (if the user writes "a   b")

                    if (!isMatchingSearch(currentFile.name))
                        continue fileloop;
                        
                    //auto composed = new Thread(&threadFunc).start();
                    new Thread({
                        resultCallback(buildFileInfo(currentFile));
                    }).start();
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