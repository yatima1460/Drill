/**
In this module go useful functions that are not strictly related to crawling
*/
module drill.core.utils;

import std.math : log, floor, pow;
import std.conv : to;




string humanSize(ulong bytes)
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

import std.datetime : SysTime;

import datefmt;

string toDateString(SysTime time)
{

	return time.format("%d/%m/%Y %H:%M:%S");

	// const string format = "";
	// char[256] buffer;
	// auto ret = strftime(buffer.ptr, buffer.ptr, toStringz(format))
	// gmtime(&timestamp);
	// return buffer[0 .. ret].idup;
}


 /***
    Opens the file using the current system implementation
    */
    void openFile(immutable(string) fullpath)
    {
		import std.process : spawnProcess;
        import std.stdio :stdin,stdout,stderr;
        import std.process : Config;

        version (Windows)
        {
           
            spawnProcess(["explorer", fullpath], stdin, stdout,
                    stderr, null, Config.detached, null);
        }
        version (linux)
        {
           
            spawnProcess(["xdg-open", fullpath], stdin, stdout,
                    stderr, null, Config.none, null);
        }
        version (OSX)
        {

            spawnProcess(["open", fullpath], stdin, stdout,
                    stderr, null, Config.none, null);
        }

        //TODO: return bool if successful
    }



void logConsole(immutable(string) message)
{
    import std.stdio : writeln;
    debug
    {
        synchronized {
            writeln(message);
        } 
    }
}