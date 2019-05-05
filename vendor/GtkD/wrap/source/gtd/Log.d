/*
 * This file is part of gir-to-d.
 *
 * gir-to-d is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License
 * as published by the Free Software Foundation, either version 3
 * of the License, or (at your option) any later version.
 *
 * gir-to-d is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with gir-to-d.  If not, see <http://www.gnu.org/licenses/>.
 */

module gtd.Log;

import core.stdc.stdlib : exit;

import std.stdio;

void warning(Args...)(Args args)
{
	static if ( is(typeof(args[$-1].fileName)) && is(typeof(args[$-1].lineNumber)) )
	{
		stderr.writef("%s %s(%s): ", Color.blue("Warning"), args[$-1].fileName, args[$-1].lineNumber);
		stderr.writeln(args[0..$-1]);
	}
	else
	{
		stderr.write(Color.blue("Warning"), ": ");
		stderr.writeln(args);
	}
}

void warningf(Args...)(Args args)
{
	static if ( is(typeof(args[$-1].fileName)) && is(typeof(args[$-1].lineNumber)) )
	{
		stderr.writef("%s %s(%s): ", Color.blue("Warning"), args[$-1].fileName, args[$-1].lineNumber);
		stderr.writefln(args[0..$-1]);
	}
	else
	{
	stderr.write(Color.blue("Warning"), ": ");
	stderr.writefln(args);
	}
}

void error(Args...)(Args args)
{
	static if ( is(typeof(args[$-1].fileName)) && is(typeof(args[$-1].lineNumber)) )
	{
		stderr.writef("%s %s(%s): ", Color.red("Error"), args[$-1].fileName, args[$-1].lineNumber);
		stderr.writeln(args[0..$-1]);
	}
	else
	{
		stderr.write(Color.red("Error"), ": ");
		stderr.writeln(args);
	}

	exit(1);
}

void errorf(Args...)(Args args)
{
	static if ( is(typeof(args[$-1].fileName)) && is(typeof(args[$-1].lineNumber)) )
	{
		stderr.writef("%s %s(%s): ", Color.red("Error"), args[$-1].fileName, args[$-1].lineNumber);
		stderr.writefln(args[0..$-1]);
	}
	else
	{
		stderr.write(Color.red("Error"), ": ");
		stderr.writefln(args);
	}

	exit(1);
}

struct Color
{
	string esc;
	string text;
	string reset;

	private static bool _useColor;
	private static bool supportsColor;

	static this()
	{
		version(Windows)
		{
			import core.sys.windows.winbase: GetStdHandle, STD_ERROR_HANDLE;
			import core.sys.windows.wincon: GetConsoleMode, SetConsoleMode;
			import core.sys.windows.windef: DWORD, HANDLE;

			if ( !isatty(stderr.fileno()) )
				return;

			DWORD dwMode;
			HANDLE err = GetStdHandle(STD_ERROR_HANDLE);

			if ( !GetConsoleMode(err, &dwMode) )
				return;

			//ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004;
			dwMode |= 0x0004;

			//Try to set VT100 support on Windows 10.
			if ( !SetConsoleMode(err, dwMode) )
				return;

			supportsColor = true;
			_useColor = true;
		}
		else version(Posix)
		{
			if ( !isatty(stderr.fileno()) )
				return;

			supportsColor = true;
			_useColor = true;
		}
	}

	void toString(scope void delegate(const(char)[]) sink) const
	{
		if ( _useColor )
		{
			sink(esc);
			sink(text);
			sink(reset);
		}
		else
		{
			sink(text);
		}
	}

	string toString() const
	{
		if ( _useColor )
			return esc ~ text ~ reset;
		else
			return text;
	}

	void useColor(bool val)
	{
		if ( supportsColor )
			_useColor = val;
	}

	static Color red(string text)
	{
		return Color("\033[1;31m", text, "\033[m");
	}

	static Color blue(string text)
	{
		return Color("\033[1;34m", text, "\033[m");
	}
}

extern(C) private int isatty(int);
