module Crawler;

import std.container : Array;
import core.thread : Thread;
import std.stdio;
import std.file;
import std.file : DirEntry;

import Utils : humanSize;
import Utils : toDateString;
import FileInfo : FileInfo;

import API : DrillAPI;

import std.algorithm : map, filter;
import std.array : array;

// debug
// {
//     import std.experimental.logger;
// }
import std.regex : Regex, regex;

import std.conv : to;
import std.algorithm : sort;
import std.array : array;
import std.path : baseName;
import std.conv : to;
import std.regex : Regex;

import std.uni : toLower;
import std.path : baseName, dirName, extension;
import std.uni : toLower;
import std.string : split, strip;
import std.algorithm : canFind;
import std.array : replace;
import std.regex : match, RegexMatch;

import Logger : Logger;

class Crawler : Thread
{
private:
    immutable(string) MOUNTPOINT;
    bool running;
    const(Regex!char[]) BLOCK_LIST_REGEX;
    const(Regex!char[]) PRIORITY_LIST_REGEX;
    // Array!DirEntry* index;
    debug
    {
        long ignored_count;
    }

    void delegate(immutable(FileInfo) result) resultCallback;

    immutable(string) search;

    // void logConsole(immutable(string) message)
    // {
    //     static import Utils;

    //     Utils.logConsole("[Core][" ~ to!string(this) ~ "] " ~ message);
    // }

public:
    // debug
    // {
    //     FileLogger log;
    // }

    // invariant(root != null);
    // invariant(root.length > 0);
    // invariant(resultCallback != null);
    // invariant(exclusion_list.length > 0);

    this(immutable(string) MOUNTPOINT, immutable(string[]) BLOCK_LIST,
            const(Regex!char[]) PRIORITY_LIST_REGEX,
            void delegate(immutable(FileInfo) result) resultFound, immutable(string) search)
    {

        //TODO: invariant root contains /

        super(&run);
        this.MOUNTPOINT = MOUNTPOINT;

        Logger.logDebug("Created");
        Logger.logDebug("Search term '" ~ search ~ "'");
        Logger.logDebug("Global blocklist.length = " ~ to!string(BLOCK_LIST.length));

        // Every Crawler will have all the other mountpoints in its blocklist
        // In this way crawlers will not cross paths
        string[] cp_tmp = DrillAPI.getMountPoints()[].filter!(x => x != MOUNTPOINT)
            .map!(x => "^" ~ x ~ "$")
            .array;
        Logger.logDebug("Adding these to the global blocklist: " ~ to!string(cp_tmp));

        Array!string crawler_exclusion_list = Array!string(BLOCK_LIST);
        crawler_exclusion_list ~= cp_tmp;

        const(Regex!char[]) exclusion_regexes = crawler_exclusion_list[].map!(x => regex(x)).array;
        this.BLOCK_LIST_REGEX = exclusion_regexes;

        Logger.logDebug("New crawler custom blocklist.length = " ~ to!string(BLOCK_LIST_REGEX.length));
        Logger.logDebug("Global priority list length = " ~ to!string(PRIORITY_LIST_REGEX.length));
        this.PRIORITY_LIST_REGEX = PRIORITY_LIST_REGEX;
        // debug {
        //     if (this.exclusion_list.length == 0)
        //         logConsole(this ~ " has an empty exclusion list!");
        // }
        //this.index = new Array!DirEntry();
        this.search = search;

        resultCallback = resultFound;
    }

    pure void stopAsync() @safe @nogc
    {
        this.running = false;
    }

    void stopSync()
    {
        this.running = false;
        this.join();
    }

    // Array!DirEntry* grab_index()
    // {
    //     Array!DirEntry* i = this.index;
    //     this.index = new Array!DirEntry();
    //     return i;
    // }

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
            {
                return true;
            }

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
        
        Logger.logTrace("Allowed, not in the blocklist: '" ~ value ~ "'");
        
        return false;
    }

    // void crawlFolder(DirEntry currentDirectory)
    // {

    //     DirIterator files = dirEntries(currentDirectory, SpanMode.shallow, true);

    //     Array!DirEntry nextLevelDirectoriesToScan;

    //     fileloop: foreach (currentFile; files)
    //     {
    //         if (currentFile.isDir() && !isBlocklisted(currentDirectory.name))
    //         {
    //             nextLevelDirectoriesToScan.insertBack(currentFile);
    //             debug{ logConsole(" Directory queued: " ~ currentFile.name);}
    //         }

    //         FileInfo f;
    //         f.isDirectory = !currentFile.isDir();
    //         f.isDirectory = currentFile.isDir();
    //         f.fullPath = currentFile.name;
    //         f.fileName = baseName(currentFile.name);

    //         f.fileNameLower = toLower(f.fileName);

    //         f.containingFolder = dirName(currentFile.name);
    //         f.extension = extension(currentFile.name);
    //         f.sizeString = humanSize(currentFile.size);
    //         f.originalMountpoint = this.MOUNTPOINT;
    //         f.dateModifiedString = toDateString(currentFile.timeLastModified());

    //         const string fileNameLower = toLower(baseName(currentFile.name));

    //         //FIXME: filter and remove empty strings (if the user writes "a   b")
    //         const string[] searchTokens = toLower(strip(search)).split(" ");
    //         //writeln(searchTokens, fileNameLower);

    //         foreach (token; searchTokens)
    //         if (!canFind(fileNameLower, token))
    //         {
    //             debug{logConsole(" Not matching search, skipped: "~fileNameLower);}
    //             continue fileloop;
    //         }
    //         else
    //         {
    //             debug{logConsole(" Matching search"~fileNameLower);}
    //         }

    //         resultCallback(f);

    //         //directoriesToScan = nextLevelDirectoriesToScan;
    //     }

    //     for (int i = 0; i < nextLevelDirectoriesToScan.length; i++)
    //     {
    //         crawlFolder(nextLevelDirectoriesToScan[i]);
    //     }
    // }

    FileInfo buildFileInfo(DirEntry currentFile)
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


    /**
    NOTE: We don't really care about CPU time, Drill isn't CPU intensive but disk intensive,
    in this function it's not bad design that there are multiple IFs checking the same thing over and over again,
    but it's done to stop the crawling as soon as possible to have more time to crawl important files.
    */
    void run()
    {

        this.running = true;

        Logger.logDebug("Started");

        //import tanya.container : Queue;
        //import lock_free.rwqueue : RWQueue;
        import std.container.dlist : DList;

        DList!DirEntry queue;

        if (isBlocklisted(MOUNTPOINT))
        {
            this.running = false;
            Logger.logDebug("Crawler mountpoint is in the blocklist, the crawler will stop.");
        }
        else
        {
            try
            {
                queue.insertBack(DirEntry(MOUNTPOINT));
            }
            catch (Exception e)
            {
                Logger.logError(e.msg);
                this.running = false;
            }
        }


        while (!queue.empty() && running)
        {

            DirEntry currentDirectory = queue.front();
            queue.removeFront();


            if (isBlocklisted(currentDirectory.name))
            {
                Logger.logTrace("Blocked: " ~ currentDirectory.name);
                continue;
            }

            if (currentDirectory.isSymlink())
            {
                Logger.logTrace("Symlink ignored: " ~ currentDirectory.name);
                continue;
            }

            
            Logger.logTrace("Current directory: " ~ currentDirectory.name);
            

            
            DirIterator files;
            
            try
            {
                files = dirEntries(currentDirectory, SpanMode.shallow, true);
            }
            catch (Exception e)
            {
                debug
                {
                    Logger.logError(e.msg);
                }
                continue;
            }

            fileloop: foreach (currentFile; files)
            {
                
                try
                {
                    if (currentFile.isSymlink())
                    {
                        Logger.logTrace("Symlink ignored: " ~ currentDirectory.name);
                        continue fileloop;
                    }
                    if (isBlocklisted(currentFile.name))
                    {
                        Logger.logTrace("File blocklisted: " ~ currentDirectory.name);
                        continue fileloop;
                    }




                    if (currentFile.isDir())
                    {
                        if (isPrioritylisted(currentFile.name))
                        {
                            Logger.logDebug("Priority listed: "~currentFile.name);
                            queue.insertFront(currentFile);
                        }
                        else
                        {
                            Logger.logTrace("Not priority listed: "~currentFile.name);
                            queue.insertBack(currentFile);
                        }
                    }

                                //FIXME: filter and remove empty strings (if the user writes "a   b")
                    const string[] searchTokens = toLower(strip(search)).split(" ");
                    //writeln(searchTokens, fileNameLower);

                      const string fileNameLower = toLower(baseName(currentFile.name));
                    foreach (token; searchTokens)
                    {
                        if (!canFind(fileNameLower, token))
                        {
                            Logger.logTrace("Not matching search, skipped: "~fileNameLower);
                            continue fileloop;
                        }
                        else
                        {
                            Logger.logTrace("Matching search"~fileNameLower);
                        }
                    }
                    resultCallback(buildFileInfo(currentFile));
                    

              
                }
                catch (Exception e)
                {
                    Logger.logError(e.msg);
                }
            }
        }

        // debug{ logConsole("Current directory: "~MOUNTPOINT);}

        // if (isBlocklisted(currentDirectory.name))
        //     return;

        // if (currentDirectory.isSymlink())
        // {
        //     debug{logConsole("Symlink ignored: " ~ currentDirectory.name);}

        // }

        // catch (std.utf.UTFException e)
        // {

        //     logConsole(e.msg);
        //     this.running = false;
        //     return;
        // }

        this.running = false;
        Logger.logDebug("Finished its job");
    }

    // Array!DirEntry* directoriesToScan = new Array!DirEntry();
    // try
    // {
    //     // add mountpoint as first directory to scan

    //     if (!isBlocklisted(this.MOUNTPOINT))
    //     {
    //         DirEntry direntryroot = DirEntry(this.MOUNTPOINT);
    //         directoriesToScan.insertBack(direntryroot);
    //     }

    //     while (directoriesToScan.length != 0 && this.running)
    //     {
    //         Array!DirEntry* nextLevelDirectoriesToScan = new Array!DirEntry();
    //         auto currentDirectory = directoriesToScan.back();
    //         debug{ logConsole("Current directory: "~currentDirectory.name);}
    //         DirIterator files = dirEntries(currentDirectory, SpanMode.shallow, true);
    //         directoriesToScan.removeBack();

    //         fileloop: foreach (currentFile; files)
    //         {
    //             
    //             
    //             
    //             
    //             

    //             if (isBlocklisted(currentFile.name))
    //                 continue;

    //             if (currentFile.isDir())
    //             {
    //                 //next_queue.insertBack(direntry);
    //                 nextLevelDirectoriesToScan.insertBack(currentFile);
    //                 //debug{ logConsole("[DIRECTORY QUEUED]\t" ~ direntry.name);}
    //             }

    //             FileInfo f;
    //             f.isDirectory = !currentFile.isDir();
    //             f.isDirectory = currentFile.isDir();
    //             f.fullPath = currentFile.name;
    //             f.fileName = baseName(currentFile.name);

    //             f.fileNameLower = toLower(f.fileName);

    //             f.containingFolder = dirName(currentFile.name);
    //             f.extension = extension(currentFile.name);
    //             f.sizeString = humanSize(currentFile.size);
    //             f.originalMountpoint = this.MOUNTPOINT;
    //             f.dateModifiedString = toDateString(currentFile.timeLastModified());

    //             const string fileNameLower = toLower(baseName(currentFile.name));

    //             //FIXME: filter and remove empty strings (if the user writes "a   b")
    //             const string[] searchTokens = toLower(strip(search)).split(" ");
    //             //writeln(searchTokens, fileNameLower);

    //             foreach (token; searchTokens)
    //                 if (!canFind(fileNameLower, token))
    //                 {
    //                     debug{logConsole(" Not matching search, skipped: "~fileNameLower);}
    //                     continue fileloop;
    //                 }
    //                 else
    //                 {
    //                     debug{logConsole(" Matching search"~fileNameLower);}
    //                 }

    //             resultCallback(f);

    //             directoriesToScan = nextLevelDirectoriesToScan;
    //         }

    //auto q = array(directories_queue);

    //    foreach (ref regexrule; this.PRIORITY_LIST_REGEX)
    // {

    //     RegexMatch!string mo1 = std.regex.match(directory1_name, regexrule);

    //     if (!mo1.empty())
    //     {
    //         directory1_found = true;
    //         break;
    //     }

    // }

    //foreach (parent; sort!(myComp)(q))
    //     foreach (parent; q)
    //     {
    //         // debug
    //         // {
    //         //     logConsole(this.toString() ~ " parent:" ~ parent);
    //         // }
    //         try
    //         {
    //             DirIterator entries = dirEntries(parent, SpanMode.shallow, true);

    //             fileloop: foreach (DirEntry direntry; entries)
    //             {
    //                 if (!this.running)
    //                     return;
    //                 //logConsole(file.size);

    //                 if (direntry.isSymlink())
    //                 {
    //                     debug{logConsole("[SYMLINK IGNORED]\t" ~ direntry.name);}
    //                     continue fileloop;
    //                 }

    //                 import std.regex;

    //                 // logConsole("Working on:" ~ file.name);
    //                 foreach (ref regexrule; this.BLOCK_LIST_REGEX)
    //                 {

    //                     // matchAll() returns a range that can be iterated
    //                     // to get all subsequent matches.
    //                     RegexMatch!string mo = std.regex.match(direntry.name, regexrule);

    //                     if (!mo.empty())
    //                     {

    //                         debug{ logConsole("[DRILL][CORE] "~this.toString()~" blocked because of regex rules: " ~ direntry.name);}

    //                         debug
    //                         {
    //                             this.ignored_count++;
    //                         }
    //                         continue fileloop;
    //                     }
    //                     else

    //                     {

    //                         //logConsole(direntry.name ~ " added");
    //                     }

    //                 }

    //                 FileInfo f;
    //                 if (direntry.isDir())
    //                 {
    //                     next_queue.insertBack(direntry);

    //                     //debug{ logConsole("[DIRECTORY QUEUED]\t" ~ direntry.name);}
    //                     f.isDirectory = true;
    //                 }
    //                 else
    //                 {
    //                     f.isFile = false;
    //                 }

    //                 // int[string] aa;

    //                 // index.insertBack(direntry);
    //                 import std.algorithm : canFind;
    //                 import std.path : baseName, dirName, extension;

    //                 // TODO split by space and search every token
    //                 import std.uni : toLower;
    //                 import std.string : split, strip;

    //                 const string fileNameLower = toLower(baseName(direntry.name));

    //                 //FIXME: filter and remove empty strings (if the user writes "a   b")
    //                 const string[] searchTokens = toLower(strip(search)).split(" ");
    //                 //writeln(searchTokens, fileNameLower);

    //                 foreach (token; searchTokens)
    //                 {
    //                     if (!canFind(fileNameLower, token))
    //                     {
    //                         //writeln("skipping...");
    //                         continue fileloop;
    //                     }

    //                 }

    //                 f.fullPath = direntry.name;
    //                 f.fileName = baseName(direntry.name);

    //                 f.fileNameLower = toLower(f.fileName);
    //                 f.containingFolder = dirName(direntry.name);
    //                 f.extension = extension(direntry.name);

    //                 f.sizeString = humanSize(direntry.size);

    //                 f.originalMountpoint = root;

    //                 f.dateModifiedString = toDateString(direntry.timeLastModified());
    //                 if (running)
    //                     resultCallback(f);

    //                 // debug{ logConsole("[FILE FOUND]\t" ~ direntry.name);}
    //                 //logConsole(direntry.name ~ " added to global index");

    //             }

    //         }
    //         catch (std.file.FileException e)
    //         {

    //             debug
    //             {
    //                 logConsole("[FILE EXCEPTION]\t" ~ e.msg);
    //             }

    //             continue;
    //         }
    //         catch (std.utf.UTFException e)
    //         {

    //             debug
    //             {
    //                 logConsole("[UTF EXCEPTION]\t" ~ parent ~ " " ~ e.msg);
    //             }

    //             continue;
    //         }
    //     }

    //     directories_queue = next_queue;

}
