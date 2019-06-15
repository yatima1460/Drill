module Utils;

/**
In this module go useful functions that are not strictly related to crawling
*/

import std.math : log, floor, pow;
import std.conv : to;

import std.functional : memoize;

string _humanSize(ulong bytes)
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

string _toDateString(SysTime time)
{
    import datefmt : format;

    return time.format("%d/%m/%Y %H:%M:%S");

    // const string format = "";
    // char[256] buffer;
    // auto ret = strftime(buffer.ptr, buffer.ptr, toStringz(format))
    // gmtime(&timestamp);
    // return buffer[0 .. ret].idup;
}

alias toDateString = memoize!_toDateString;

/***
    Opens the file using the current system implementation
    */
bool openFile(immutable(string) fullpath) @system
{
    import std.process : spawnProcess;
    import std.stdio : stdin, stdout, stderr;
    import std.process : Config;
    import Logger : Logger;

    version (Windows)
    {
        try
        {
            spawnProcess(["explorer", fullpath], stdin, stdout, stderr, null,
                    Config.detached, null);
            return true;
        }
        catch (Exception e)
        {
            Logger.logError(e.msg);
            return false;
        }
    }
    version (linux)
    {
        immutable(string[]) FILE_OPENERS = [
            "gvfs-open", "gnome-open", "kde-open", "exo-open", "xdg-open"
        ];

        static foreach (OPENER; FILE_OPENERS)
        {
            try
            {
                spawnProcess([OPENER, fullpath], stdin, stdout, stderr, null,
                        Config.detached, null);
                return true;
            }
            catch (Exception e)
            {
                Logger.logError(e.msg);
            }
        }
        return false;
    }
    version (OSX)
    {
        try
        {
            spawnProcess(["open", fullpath], stdin, stdout, stderr, null, Config.detached, null);
            return true;
        }
        catch (Exception e)
        {
            Logger.logError(e.msg);
            return false;
        }
    }

    //TODO: return bool if successful?
}

// void logConsole(immutable(string) message)
// {
//     import std.stdio : writeln;
//     synchronized {
//         writeln(message);
//     } 
// }

string[] readListFiles(immutable(string) path)
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

// void showInfoMessagebox(immutable(string) message)
// {

//         logConsole("showMessagebox "~message);
// 		//version (linux)
// 		//{
// 		//    import std.process : executeShell;
// 		//    executeShell("zenity --info --text=\""~message~"\" --title=\"Drill\" --width=160 --height=90");
// 		//
// 		//    //TODO: if failed call this
// 		//    //executeShell("xmessage -center \""~title~":"~message~"\"");
// 		//}
// 		//version (Windows)
// 		//{	
// 		//    import std.utf : toUTF16z;
// 		//    import core.sys.windows.windows;
// 		//
// 		//    MessageBox(NULL, message.toUTF16z, "Drill", 0);
// 		//}
// 		//version (OSX)
// 		//{
// 		//
// 		//}
//     }

// void showWarningMessagebox(immutable(string) message)
// {
// 	logConsole("showMessagebox "~message);
// 		//version(CLI)
// 		//{
// 		//    
// 		//}
// 		//else
// 		//{
// 		//    version (linux)
// 		//    {
// 		//        import std.process : executeShell;
// 		//        executeShell("zenity --warning --text=\""~message~"\" --title=\"Drill\" --width=160 --height=90");
// 		//
// 		//        //TODO: if failed call this
// 		//        //executeShell("xmessage -center \""~title~":"~message~"\"");
// 		//    }
// 		//    version (Windows)
// 		//    {
// 		//
// 		//    }
// 		//    version (OSX)
// 		//    {
// 		//
// 		//    }
// 		//}

//     }

// void showErrorMessagebox(immutable(string) message)
// {

//         logConsole("showMessagebox "~message);
// 		//version (linux)
// 		//{
// 		//    import std.process : executeShell;
// 		//    executeShell("zenity --error --text=\""~message~"\" --title=\"Drill\" --width=160 --height=90");
// 		//
// 		//    //TODO: if failed call this
// 		//    //executeShell("xmessage -center \""~title~":"~message~"\"");
// 		//}
// 		//version (Windows)
// 		//{
// 		//
// 		//}
// 		//version (OSX)
// 		//{
// 		//
// 		//}
//     }
