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

module gtd.IndentedStringBuilder;

import std.algorithm: canFind, startsWith, endsWith;
import std.range: empty;
import std.string: strip;

/** Keeps track of indentation level while building up a string */
public class IndentedStringBuilder
{
	string tabs;
	bool statement;
	bool paramList;

	this()
	{
		this("");
	}

	this(string t)
	{
		tabs = t;
	}

	/**
	 * Formats the input line while keeping track of indentation.
	 * Params:
	 *    	lines = The lines to format
	 */
	public string format(string line)
	{
		string text;
		line = line.strip();

		if ( (endsWith(line, '{') && !startsWith(line, "}")) || endsWith(line, "(") )
		{
			statement = false;
		}

		//Don't change the indentation when the line is a comment.
		if ( startsWith(line, '*') )
		{
			return tabs ~" "~ line ~ "\n";
		}

		if ( endsWith(line, "}", "};") || startsWith(line, "}", "};") || line == "));" || line == "connectFlags);" || (paramList && endsWith(line, ");", ")")) )
		{
			if ( !canFind(line, '{') && tabs.length > 0 )
				tabs.length = tabs.length -1;

			if ( line == "connectFlags);" )
				statement = true;

			if ( endsWith(line, ");") && !endsWith(line, "));") && line != ");" )
				statement = true;

			paramList = false;
		}

		if ( line.empty )
		{
			return "\n";
		}
		else if ( startsWith(line, "&&", "||") )
		{
			text = tabs ~"\t"~ line ~"\n";
		}
		else if ( statement )
		{
			text = tabs ~"\t"~ line ~"\n";
			statement = false;
		}
		else
		{
			text = tabs ~ line ~"\n";
		}

		if ( startsWith(line, "if", "else", "static if","version", "debug", "do", "while") && !endsWith(line, "}", ";") )
		{
			statement = true;
		}
		else if ( (endsWith(line, '{') && !startsWith(line, "}")) )
		{
			tabs ~= '\t';
		}
		else if ( endsWith(line, "(") )
		{
			tabs ~= '\t';
			paramList = true;
		}

		return text;
	}

	/**
	 * Formats the input lines while keeping track of indentation
	 * Params:
	 *    	lines = The lines to format
	 */
	public string format(string[] lines)
	{
		string text = "";
		foreach(string line ; lines )
			text ~= format(line);
		return text;
	}

	public void setIndent(string t)
	{
		tabs = t;
	}
}
