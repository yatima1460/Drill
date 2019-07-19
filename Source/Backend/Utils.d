module Utils;

/**
In this module go useful functions that are not strictly related to crawling
*/

import std.math : log, floor, pow;
import std.conv : to;
import std.algorithm : canFind;
import std.functional : memoize;
import std.process : executeShell;
import std.file : dirEntries, SpanMode, DirEntry, readText, FileException;
import std.array : array, split;

import ApplicationInfo : ApplicationInfo;

import Logger : Logger;


/**
Opens a file using the current system implementation for file associations

Returns: true if successful
*/
bool drill_open_file(immutable(string) fullpath) @system
{
    import std.process : spawnProcess;
    import std.stdio : stdin, stdout, stderr;
    import std.process : Config;
    import Logger : Logger;
    
    try
    {
        version (Windows) spawnProcess(["explorer", fullpath], null, Config.none, null);
        version (linux) spawnProcess(["xdg-open", fullpath], null, Config.none, null);
        version (OSX) spawnProcess(["open", fullpath], null, Config.none, null);
        return true;
    }
    catch (Exception e)
    {
        Logger.logError(e.msg);
        return false;
    }
}




















string[] _cleanExecLine(immutable(string) exec) pure @safe
{
    import std.algorithm : filter;
    import std.array : array, split;
    return exec.split(" ")[].filter!(x => x[0 .. 1] != "%").array;
}
alias cleanExecLine = memoize!_cleanExecLine;


immutable(ApplicationInfo) readDesktopFile(immutable(string) fullPath) @system
{
    string[] desktopFileLines;
   

    string desktopFileDateModifiedString;

    try
    {
            import std.algorithm : filter;

    import std.array : array;
        desktopFileLines = readText(fullPath).split("\n");
        desktopFileLines = desktopFileLines.filter!(x => x.length != 0).array;
        desktopFileDateModifiedString = toDateString(DirEntry(fullPath).timeLastModified);
    }
    catch (Exception e)
    {
        Logger.logError("Error reading file: '" ~ fullPath~ "' "~e.msg);
    }
    
    
    string desktopFileFullPath = fullPath;
    string exec;
    string[] execProcess;
    string name;
    string icon;
   
    try
    {

        
        foreach (line; desktopFileLines)
        {
            if (line.length < 5) continue;
            // ai.exec.length == 0 &&
            // is used so we only assign the first line found
        
            if (exec.length == 0 && canFind(line[0..5],"Exec="))
            {
                exec = line[5..$];
                execProcess = cleanExecLine(line[5..$]);
            }
            if (name.length == 0 && canFind(line[0..5],"Name="))
            {
                name = line[5..$];
            }
            if (canFind(line[0..5],"Icon="))
            {
                icon = line[5..$];
            }
            
        }
    }
    catch (Exception e)
    {
        Logger.logError("Error parsing file: '" ~ fullPath~ "' "~e.msg);
    }

    immutable(ApplicationInfo) ai = {
        name,
        desktopFileFullPath,
        exec,
        cast(immutable(string[]))execProcess,
        icon,
        cast(immutable(string))desktopFileDateModifiedString
    };
    return ai;
}
//alias readDesktopFile = memoize!_readDesktopFile;


string _humanSize(ulong bytes) @safe
{
    string[] suffix = ["B", "KB", "MB", "GB", "TB"];

    int i = 0;
    double dblBytes = bytes;

    if (bytes > 1024)
    {
        for (i = 0; (bytes / 1024) > 0; i++, bytes /= 1024)
            dblBytes = bytes / 1024.0;
    }

    return to!string(floor(dblBytes)) ~ " " ~ suffix[i];
}

alias humanSize = memoize!_humanSize;

import std.datetime : SysTime;

string _toDateString(SysTime time) @safe
{
    import std.array : array, replace;
    return time.toISOExtString().replace("T"," ").replace("-","/").split(".")[0];
}
alias toDateString = memoize!_toDateString;




string[] readListFiles(immutable(string) path) @system
{
    import std.file : dirEntries, SpanMode, DirEntry, readText, FileException;

    string[] temp_blocklist = [];

    auto blocklists_file = dirEntries(DirEntry(path), SpanMode.shallow, true);

    foreach (string partial_blocklist; blocklists_file)
    {
        import std.array : split;

        temp_blocklist ~= readText(partial_blocklist).split("\n");
    }

    // remove empty newlines
    import std.algorithm : filter;

    import std.array : array;

    return temp_blocklist.filter!(x => x.length != 0).array;
}
//alias readListFiles = memoize!_readListFiles;
