
/**
In this module go useful functions that are not strictly related to crawling
*/
import std.functional : memoize;

import std.typecons : Tuple;

Tuple!(int,"status",string,"output") executeShellThreadSafe(immutable(string) str)
{
    synchronized
    {
        import std.process : executeShell;
        return executeShell(str);
    }
}


version(linux) @system string[] getDesktopFiles() 
{
    synchronized
    {
        
        import std.array : split;
        import Logger : Logger;
        //HACK: replace executeShell with a system call to get the list of files, executeShell is SLOW
        immutable auto ls = executeShellThreadSafe("ls /usr/share/applications/*.desktop | grep -v _");
        if (ls.status == 0)
        {   
            return ls.output.split("\n");
        }
        Logger.logError("Can't retrieve applications, will return an empty list");
        return [];
    }
}





/**
Opens a file using the current system implementation for file associations

Returns: true if successful
*/
nothrow @safe bool openFile(in immutable(string) fullpath)
{
    synchronized
    {
        import std.process : spawnProcess;
        import std.stdio : stdin, stdout, stderr;
        import std.process : Config;

        import Logger : Logger;

        try
        {
            version (Windows)
                spawnProcess(["explorer", fullpath], null, Config.none, null);
            version (linux)
                spawnProcess(["xdg-open", fullpath], null, Config.none, null);
            version (OSX)
                spawnProcess(["open", fullpath], null, Config.none, null);
            // FIXME: if all three false it will return true even when it should be false
            return true;
        }
        catch (Exception e)
        {
            Logger.logError(e.msg);
            return false;
        }
    }
}

import std.datetime : SysTime;
@safe string _sysTimeToHumanReadable(in SysTime time)
out (s; s.length != 0)
{
    import std.array : array, replace, split;
    return time.toISOExtString().replace("T", " ").replace("-", "/").split(".")[0];
}
alias systime_to_string = memoize!_sysTimeToHumanReadable;


/**
Returns the mount points of the current system
It's not assured that every mount point is a physical disk

Returns: immutable array of full paths
*/
immutable(string[]) getMountpoints() @trusted
out(m; m.length != 0)
{
    import std.process : executeShell;
    import Logger : Logger;

    synchronized
    {
        version (linux)
        {
            // df catches network mounted drives like NFS
            // so don't use lsblk here

            immutable auto ls = executeShellThreadSafe("df -h --output=target");

            if (ls.status != 0)
            {
                Logger.logError("Can't retrieve mount points, will just scan '/'");
                return ["/"];
            }
            import std.array : array, split;
            import std.algorithm : filter, canFind;

            auto result = array(ls.output.split("\n").filter!(x => canFind(x, "/"))).idup;
            //debug{logConsole("Mount points found: "~to!string(result));}
            return result;
        }
        version (OSX)
        {
            immutable auto ls = executeShellThreadSafe("df -h");
            if (ls.status != 0)
            {
                Logger.logError("Can't retrieve mount points, will just scan '/'");
                return ["/"];
            }
            immutable auto startColumn = indexOf(ls.output.split("\n")[0], 'M');
            auto result = array(ls.output.split("\n").filter!(x => x.length > startColumn)
                    .map!(x => x[startColumn .. $])
                    .filter!(x => canFind(x, "/"))).idup;
            //debug{logConsole("Mount points found: "~result);}
            return result;
        }
        version (Windows)
        {
            immutable auto ls = executeShellThreadSafe("wmic logicaldisk get caption");
            if (ls.status != 0)
            {
                Logger.logError("Can't retrieve mount points, will just scan 'C:'");
                return ["C:"];
            }

            auto result = array(map!(x => x[0 .. 2])(ls.output.split("\n")
                    .filter!(x => canFind(x, ":")))).idup;
            //debug{logConsole("Mount points found: "~result);}
            return result;
        }
    }
}



@safe string _sizeToHumanReadable(in ulong bytes)
out(m; m.length != 0)
{
    immutable(string[]) sizes = ["B", "KB", "MB", "GB", "TB", "PB", "EB"];
    double len = cast(double) bytes;
    int order = 0;
    
    while (len >= 1024)
    {
        order++;
        len = len / 1024;
    }

    import std.format : format;

    if (order >= sizes.length)
        return format("%#.2f", len) ~ " ?B";
    else
        return format("%#.2f", len) ~ " " ~ sizes[order];
}

alias sizeToHumanReadable = memoize!_sizeToHumanReadable;

import ApplicationInfo : ApplicationInfo;
version(linux) immutable(ApplicationInfo) readDesktopFile(immutable(string) fullPath) @system
{
    import Logger : Logger;

    string[] desktopFileLines;

    string desktopFileDateModifiedString;

    try
    {
        import std.algorithm : filter;

        import std.array : array, split;
        import std.file : dirEntries, SpanMode, DirEntry, readText, FileException;

        desktopFileLines = readText(fullPath).split("\n");
        desktopFileLines = desktopFileLines.filter!(x => x.length != 0).array;
        desktopFileDateModifiedString = systime_to_string(DirEntry(fullPath).timeLastModified);
    }
    catch (Exception e)
    {
        Logger.logError("Error reading file: '" ~ fullPath ~ "' " ~ e.msg);
    }

    string desktopFileFullPath = fullPath;
    string exec;
    string[] execProcess;
    string name;
    string icon;

    import std.algorithm : canFind;

    try
    {

        foreach (line; desktopFileLines)
        {
            if (line.length < 5)
                continue;
            // ai.exec.length == 0 &&
            // is used so we only assign the first line found

            if (exec.length == 0 && canFind(line[0 .. 5], "Exec="))
            {
                exec = line[5 .. $];
                execProcess = cleanExecLine(line[5 .. $]);
            }
            if (name.length == 0 && canFind(line[0 .. 5], "Name="))
            {
                name = line[5 .. $];
            }
            if (canFind(line[0 .. 5], "Icon="))
            {
                icon = line[5 .. $];
            }

        }
    }
    catch (Exception e)
    {
        Logger.logError("Error parsing file: '" ~ fullPath ~ "' " ~ e.msg);
    }

    immutable(ApplicationInfo) ai = {
        name, desktopFileFullPath, exec, cast(immutable(string[])) execProcess,
            icon, cast(immutable(string)) desktopFileDateModifiedString
    };
    return ai;
}

version(linux) string[] _cleanExecLine(immutable(string) exec) pure @safe
{
    import std.algorithm : filter;
    import std.array : array, split;
    
    return exec.split(" ")[].filter!(x => x.length >= 1 && x[0 .. 1] != "%").array;
}
version(linux) alias cleanExecLine = memoize!_cleanExecLine;



string[] mergeAllTextFilesInDirectory(immutable(string) path) @system 
{
    import std.file : dirEntries, SpanMode, DirEntry, readText, FileException;

    string[] temp_blocklist = [];

    import std.algorithm : filter;
    import std.string : endsWith;

    auto blocklists_file = dirEntries(path, SpanMode.shallow, true).filter!(f => f.name.endsWith(".txt"));

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
