
/**
In this module go useful functions that are not strictly related to crawling
*/
import std.functional : memoize;
import std.typecons : Tuple;
import std.experimental.logger;
import std.uni : toLower;
import std.path : extension;
import std.process : executeShell;



version(linux) @system string[] getDesktopFiles()
{
    synchronized
    {
        import std.algorithm : canFind, filter, map;
        import std.array : array;
        import std.file : dirEntries, SpanMode;
        try
        {
            return dirEntries("/usr/share/applications", "*.desktop", SpanMode.depth)
                .map!(a => a.name)
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
    import std.process : spawnProcess;
    import std.stdio : stdin, stdout, stderr;
    import std.process : Config;
    import std.process : executeShell;

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
                    info("File "~fullpath~" detected as .AppImage");
                    immutable auto cmd = executeShell("chmod +x "~fullpath);
                    if (cmd.status != 0)
                    {
                        critical("Can't set AppImage '"~fullpath~"' as executable.");
                        // TODO: GTK messagebox here or throw a DrillException?
                        return false;
                    }
                    spawnProcess([fullpath], null, Config.detached, null);
                    return true;

                default:
                    info("Generic file "~fullpath~", will use xdg-open.");
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
string[] _getMountpoints() @trusted
out(m; m.length != 0)
{
    import std.process : executeShell;
   

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
            import std.array : array, split;
            import std.algorithm : filter, canFind;

            auto result = array(ls.output.split("\n").filter!(x => canFind(x, "/"))).idup;
            //debug{logConsole("Mount points found: "~to!string(result));}
            return cast(string[])result;
        }
        version (OSX)
        {
            immutable auto ls = executeShell("df -h");
            if (ls.status != 0)
            {
                critical("Can't retrieve mount points, will just scan '/'");
                return ["/"];
            }
            import std.string : indexOf;
            import std.array : array, split;
            import std.algorithm : map, canFind, filter;
            immutable auto startColumn = indexOf(ls.output.split("\n")[0], 'M');
            auto result = array(ls.output.split("\n").filter!(x => x.length > startColumn)
                    .map!(x => x[startColumn .. $])
                    .filter!(x => canFind(x, "/"))).idup;
            //debug{logConsole("Mount points found: "~result);}
            return cast(string[])result;
        }
        version (Windows)
        {
            immutable auto ls = executeShell("wmic logicaldisk get caption");
            if (ls.status != 0)
            {
                critical("Can't retrieve mount points, will just scan 'C:'");
                return ["C:"];
            }
            import std.array : array, split;
            import std.algorithm : map, canFind, filter;
            auto result = array(map!(x => x[0 .. 2])(ls.output.split("\n")
                    .filter!(x => canFind(x, ":")))).idup;
            //debug{logConsole("Mount points found: "~result);}
            return cast(string[])result;
        }
    }
}
alias getMountpoints = memoize!_getMountpoints;


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
in (fullPath !is null)
in (fullPath.length > 0,"fullPath to the desktop file can't be zero length")
out (app;app.name !is null,"app name can't be null: "~fullPath)
out (app;app.name.length > 0)
// out (app;app.exec !is null,"app exec can't be null: "~fullPath)
// out (app;app.exec.length > 0,"app exec can't be length 0: "~fullPath)
{
    

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
        error("Error reading file: '" ~ fullPath ~ "' " ~ e.msg);
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
        error("Error parsing file: '" ~ fullPath ~ "' " ~ e.msg);
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
