/**
In this module go useful functions that are not strictly related to crawling
*/
import std.functional : memoize;
import std.typecons : Tuple;
import std.experimental.logger;
import std.uni : toLower;
import std.path : extension;
import std.process : executeShell;
import std.algorithm : canFind, filter, map;
import std.process : spawnProcess;
import std.stdio : stdin, stdout, stderr;
import std.process : Config;
import std.datetime : SysTime;
import std.array : array, replace, split;
import std.array : array, split;
import std.algorithm : filter, canFind;
import std.string : indexOf;
import std.array : array, split;
import std.algorithm : map, canFind, filter;
import std.format : format;
import std.algorithm : filter;
import std.array : array, split;
import std.file : dirEntries, SpanMode, DirEntry, readText, FileException;
import std.algorithm : canFind;
import std.array : array, split;
import std.string : endsWith;
import std.array : split;
import std.array : array, split;
import std.algorithm : map, canFind, filter;
import std.path : baseName, dirName, extension;
import std.string : split, strip;

import ApplicationInfo : ApplicationInfo;

pure @safe bool isTokenizedStringMatchingString(const(string) searchString, const(string) str)
{
    if (str.length < searchString.length)
        return false;
    const string[] searchTokens = toLower(strip(searchString)).split(" ");
    const string fileNameLower = toLower(baseName(str));
    foreach (token; searchTokens)
        if (!canFind(fileNameLower, token))
            return false;
    return true;
}

@safe unittest
{
    assert(isTokenizedStringMatchingString(".", "."));
    assert(isTokenizedStringMatchingString("a", "a"));
    assert(isTokenizedStringMatchingString("aaaa", "aaaaa"));
    assert(!isTokenizedStringMatchingString("aaaaa", "aaaa"));
    assert(isTokenizedStringMatchingString("jojo 39",
            "JoJo's Bizarre Adventures Golden Wind 39.mkv"));
    assert(!isTokenizedStringMatchingString("jojo 38",
            "JoJo's Bizarre Adventures Golden Wind 39.mkv"));
    assert(isTokenizedStringMatchingString("jojo 3",
            "JoJo's Bizarre Adventures Golden Wind 39.mkv"));
    assert(!isTokenizedStringMatchingString("jojo3",
            "JoJo's Bizarre Adventures Golden Wind 39.mkv"));
    assert(isTokenizedStringMatchingString("jojo", "JoJo's Bizarre Adventures Golden Wind 39.mkv"));
    assert(isTokenizedStringMatchingString("39", "JoJo's Bizarre Adventures Golden Wind 39.mkv"));
    assert(isTokenizedStringMatchingString("olde", "JoJo's Bizarre Adventures Golden Wind 39.mkv"));
    assert(isTokenizedStringMatchingString("JoJo's Bizarre Adventures Golden Wind 39.mkv",
            "JoJo's Bizarre Adventures Golden Wind 39.mkv"));
    assert(isTokenizedStringMatchingString(".mkv", "JoJo's Bizarre Adventures Golden Wind 39.mkv"));
}

version (linux) string[] getDesktopFiles()
{
    synchronized
    {

        try
        {
            return dirEntries("/usr/share/applications", "*.desktop", SpanMode.depth).map!(
                    a => a.name)
                .filter!(name => !name.canFind('_'))
                .array;
        }
        catch (Exception _)
        {
            error("Can't retrieve applications, will return an empty list");
            return [];
        }
    }
}

/**
Opens a file using the current system implementation for file associations

Returns: true if successful
*/
@safe bool openFile(immutable string fullpath)
{
    // FIXME: return false when no file association

    try
    {
        version (Windows)
        {
            spawnProcess(["explorer", fullpath], null, Config.detached, null);
            return true;
        }
        version (linux)
        {
            immutable auto ext = toLower(extension(fullpath));
            switch (ext)
            {
            case ".appimage":
                info("File " ~ fullpath ~ " detected as .AppImage");
                immutable auto cmd = executeShell("chmod +x " ~ fullpath);
                if (cmd.status != 0)
                {
                    critical("Can't set AppImage '" ~ fullpath ~ "' as executable.");
                    // TODO: GTK messagebox here or throw a DrillException?
                    return false;
                }
                spawnProcess([fullpath], null, Config.detached, null);
                return true;

            default:
                info("Generic file " ~ fullpath ~ ", will use xdg-open.");
                spawnProcess(["xdg-open", fullpath], null, Config.detached, null);
                return true;
            }
        }
        version (OSX)
        {
            spawnProcess(["open", fullpath], null, Config.detached, null);
            return true;
        }
    }
    catch (Exception e)
    {
        error(e.msg);
        return false;
    }
}

@safe nothrow string _sysTimeToHumanReadable(in SysTime time)
out(s; s.length != 0)
{

    return time.toISOExtString().replace("T", " ").replace("-", "/").split(".")[0];
}

alias systime_to_string = memoize!_sysTimeToHumanReadable;

/**
Returns the mount points of the current system
It's not assured that every mount point is a physical disk

Returns: immutable array of full paths
*/
@safe string[] _getMountpoints()
out(m; m.length != 0)
{

    synchronized
    {
        version (linux)
        {
            // TODO: read /proc/mounts instead of executing df
            // TODO: remove memoization
            // df catches network mounted drives like NFS
            // so don't use lsblk here

            immutable auto ls = executeShell("df -h --output=target");

            if (ls.status != 0)
            {
                critical("Can't retrieve mount points, will just scan '/'");
                return ["/"];
            }

            auto result = array(ls.output.split("\n").filter!(x => canFind(x, "/")));
            //debug{logConsole("Mount points found: "~to!string(result));}
            return result;
        }
        version (OSX)
        {
            immutable auto ls = executeShell("df -h");
            if (ls.status != 0)
            {
                critical("Can't retrieve mount points, will just scan '/'");
                return ["/"];
            }

            immutable auto startColumn = indexOf(ls.output.split("\n")[0], 'M');
            auto result = array(ls.output.split("\n").filter!(x => x.length > startColumn)
                    .map!(x => x[startColumn .. $])
                    .filter!(x => canFind(x, "/")));
            //debug{logConsole("Mount points found: "~result);}
            return result;
        }
        version (Windows)
        {
            immutable auto ls = executeShell("wmic logicaldisk get caption");
            if (ls.status != 0)
            {
                critical("Can't retrieve mount points, will just scan 'C:'");
                return ["C:"];
            }

            string[] result = array(map!(x => x[0 .. 2])(ls.output.split("\n").filter!(x => canFind(x, ":"))));
            //debug{logConsole("Mount points found: "~result);}
            return result;
        }
    }
}

alias getMountpoints = memoize!_getMountpoints;

/++
    Given a size of a file in ulong bytes will return a human readable format
+/
@safe string sizeToHumanReadable(in ulong bytes)
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

    return format("%#.2f", len) ~ " " ~ sizes[order];
}

@safe unittest
{
    assert(sizeToHumanReadable(0) == "0.00 B",);
    assert(sizeToHumanReadable(1023) == "1023.00 B");
    assert(sizeToHumanReadable(1024) == "1.00 KB");
    assert(sizeToHumanReadable(1024 * 1024) == "1.00 MB");
    assert(sizeToHumanReadable(1024 * 1023) == "1023.00 KB");
    // max value
    assert(sizeToHumanReadable(18_446_744_073_709_551_615uL) == "16.00 EB");
}

version (linux) nothrow @safe immutable(ApplicationInfo) readDesktopFile(immutable(string) fullPath)
in(fullPath !is null)
in(fullPath.length > 0, "fullPath to the desktop file can't be zero length")
out(app; app.name !is null, "app name can't be null: " ~ fullPath)
out(app; app.name.length > 0) // out (app;app.exec !is null,"app exec can't be null: "~fullPath)
// out (app;app.exec.length > 0,"app exec can't be length 0: "~fullPath)
{
   
    string[] desktopFileLines;

    string desktopFileDateModifiedString;

    try
    {

        desktopFileLines = readText(fullPath).split("\n");
        desktopFileLines = desktopFileLines.filter!(x => x.length != 0).array;
        desktopFileDateModifiedString = systime_to_string(DirEntry(fullPath).timeLastModified);
    }
    catch (Exception e)
    {
        error("Error reading file: '" ~ fullPath ~ "' " ~ e.msg);
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
        error("Error parsing file: '" ~ fullPath ~ "' " ~ e.msg);
    }

    immutable(ApplicationInfo) ai = {
        name, desktopFileFullPath, exec, cast(immutable(string[])) execProcess,
            icon, cast(immutable(string)) desktopFileDateModifiedString
    };
    return ai;
}

@safe nothrow pure version (linux) string[] _cleanExecLine(immutable(string) exec) pure @safe
{

    return exec.split(" ")[].filter!(x => x.length >= 1 && x[0 .. 1] != "%").array;
}

version (linux) alias cleanExecLine = memoize!_cleanExecLine;

@trusted string[] mergeAllTextFilesInDirectory(immutable(string) path) 
{

    string[] temp_blocklist = [];

    auto blocklists_file = dirEntries(path, SpanMode.shallow, true).filter!(
            f => f.name.endsWith(".txt"));

    foreach (string partial_blocklist; blocklists_file)
    {

        temp_blocklist ~= readText(partial_blocklist).split("\n");
    }

    // remove empty newlines

    return temp_blocklist.filter!(x => x.length != 0).array;
}
