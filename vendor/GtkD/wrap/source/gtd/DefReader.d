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

module gtd.DefReader;

import std.algorithm;
import std.array;
import std.conv : hexString;
import std.file;
import std.string : splitLines, strip, indexOf;

import gtd.WrapException;

public final class DefReader
{
	string fileName;
	string key;
	string subKey;
	string value;

	private size_t _lineNumber;
	private size_t lineOffset;
	private string[] lines;

	public this(string fileName)
	{
		this.fileName = fileName;

		lines = readText(fileName).splitLines();
		//Skip utf8 BOM.
		lines[0].skipOver(hexString!"efbbbf");

		this.popFront();
	}

	/**
	 * Proccess the _lines defined in lines.
	 * The fileName and lineOffset are only used for error reporting.
	 */
	public this(string[] lines, string fileName = "", size_t lineOffset = 0)
	{
		this.lines = lines;
		this.fileName = fileName;
		this.lineOffset = lineOffset;
		this.popFront();
	}

	public void popFront()
	{
		string line;

		if ( !lines.empty )
		{
			line = lines.front.strip();
			lines.popFront();
			_lineNumber++;

			while ( !lines.empty && ( line.empty || line.startsWith("#") ) )
			{
				line = lines.front.strip();
				lines.popFront();
				_lineNumber++;
			}
		}

		if ( !line.empty && !line.startsWith("#") )
		{
			ptrdiff_t index = line.indexOf(':');

			key    = line[0 .. max(index, 0)].strip();
			value  = line[index +1 .. $].strip();
			subKey = "";

			index = key.indexOf(' ');
			if ( index != -1 )
			{
				subKey = key[index +1 .. $].strip();
				key    = key[0 .. index].strip();
			}
		}
		else
		{
			key.length = 0;
			value.length = 0;
			subKey.length = 0;
		}
	}

	/**
	 * Gets the content of a block value
	 */
	public string[] readBlock(string key = "")
	{
		string[] block;

		if ( key.empty )
			key = this.key;

		while ( !lines.empty )
		{
			if ( startsWith(lines.front.strip(), key) )
			{
				lines.popFront();
				_lineNumber++;
				return block;
			}

			block ~= lines.front ~ '\n';
			lines.popFront();
			_lineNumber++;
		}

		throw new LookupException(this, "Found EOF while expecting: \""~key~": end\"");
	}

	/**
	 * Skip the content of a block. Supports nested blocks.
	 */
	public void skipBlock(string key = "")
	{
		if ( key.empty )
			key = this.key;

		size_t nestedBlocks = 1;
		do
		{
			do lines.popFront; while ( !lines.front.strip().startsWith(key) );

			if ( lines.front.strip().endsWith("start") )
				nestedBlocks++;
			else
				nestedBlocks--;
		}
		while ( nestedBlocks > 0 );
	}

	/**
	 * Gets the current value as a bool
	 */
	public @property bool valueBool() const
	{
		return !!value.among("1", "ok", "OK", "Ok", "true", "TRUE", "True", "Y", "y", "yes", "YES", "Yes");
	}

	public @property bool empty() const
	{
		return lines.empty && key.empty;
	}

	public @property size_t lineNumber() const
	{
		return _lineNumber + lineOffset;
	}
}

class LookupException : WrapException
{
	this(DefReader defReader, string msg)
	{
		super(msg, defReader.fileName, defReader.lineNumber);
	}
}
