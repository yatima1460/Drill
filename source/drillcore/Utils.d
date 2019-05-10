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
