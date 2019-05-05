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

module gtd.GirEnum;

import std.array : split;
import std.algorithm;
import std.range : back, empty;
import std.string : splitLines, strip, toUpper;
import std.uni : isNumber;

import gtd.GirPackage;
import gtd.GirWrapper;
import gtd.Log;
import gtd.XMLReader;

final class GirEnum
{
	string name;
	string cName;
	string libVersion;
	string doc;

	GirEnumMember[] members;
	GirWrapper wrapper;
	GirPackage pack;

	this(GirWrapper wrapper, GirPackage pack)
	{
		this.wrapper = wrapper;
		this.pack = pack;
	}

	void parse(T)(XMLReader!T reader)
	{
		name = reader.front.attributes["name"];
		cName = reader.front.attributes["c:type"];

		if ( "version" in reader.front.attributes )
			libVersion = reader.front.attributes["version"];
		reader.popFront();

		while ( !reader.empty && !reader.endTag("bitfield", "enumeration") )
		{
			switch (reader.front.value)
			{
				case "doc":
					reader.popFront();
					doc ~= reader.front.value;
					reader.popFront();
					break;
				case "doc-deprecated":
					reader.popFront();
					doc ~= "\n\nDeprecated: "~ reader.front.value;
					reader.popFront();
					break;
				case "member":
					if ( reader.front.attributes["name"].startsWith("2bu", "2bi", "3bu") )
					{
						reader.skipTag();
						break;
					}

					GirEnumMember member = GirEnumMember(wrapper);
					member.parse(reader);
					members ~= member;
					break;
				case "function":
					//Skip these functions for now
					//as they are also availabe as global functions.
					//pack.parseFunction(reader);
					reader.skipTag();
					break;
				default:
					error("Unexpected tag: ", reader.front.value, " in GirEnum: ", name, reader);
			}
			reader.popFront();
		}
	}

	string[] getEnumDeclaration()
	{
		string[] buff;
		if ( doc !is null && wrapper.includeComments )
		{
			buff ~= "/**";
			foreach ( line; doc.splitLines() )
				buff ~= " * "~ line.strip();

			if ( libVersion )
			{
				buff ~= " *";
				buff ~= " * Since: "~ libVersion;
			}

			buff ~= " */";
		}

		buff ~= "public enum "~ cName ~(name.among("ParamFlags", "MessageType") ? " : uint" : "");
		buff ~= "{";

		foreach ( member; members )
		{
			buff ~= member.getEnumMemberDeclaration();
		}

		buff ~= "}";
		if ( name !is null && pack.name.among("glgdk", "glgtk") )
			buff ~= "alias "~ cName ~" GL"~ name ~";";
		else if ( name !is null && pack.name != "pango" )
			buff ~= "alias "~ cName ~" "~ name ~";";

		return buff;
	}
}

struct GirEnumMember
{
	string name;
	string value;
	string doc;

	GirWrapper wrapper;

	@disable this();

	this(GirWrapper wrapper)
	{
		this.wrapper = wrapper;
	}

	void parse(T)(XMLReader!T reader)
	{
		name = reader.front.attributes["name"];
		value = reader.front.attributes["value"];

		if ( name.empty )
			name = reader.front.attributes["c:identifier"].split("_").back;
		
		if ( reader.front.type == XMLNodeType.EmptyTag )
			return;

		reader.popFront();

		while ( !reader.empty && !reader.endTag("member", "constant") )
		{
			switch (reader.front.value)
			{
				case "doc":
					reader.popFront();
					doc ~= reader.front.value;
					reader.popFront();
					break;
				case "doc-deprecated":
					reader.popFront();
					doc ~= "\n\nDeprecated: "~ reader.front.value;
					reader.popFront();
					break;
				case "type":
					if ( reader.front.attributes["name"] == "utf8" )
						value = "\""~ value ~"\"";
					break;
				default:
					error("Unexpected tag: ", reader.front.value, " in GirEnumMember: ", name, reader);
			}
			reader.popFront();
		}
	}

	string[] getEnumMemberDeclaration()
	{
		string[] buff;
		if ( doc !is null && wrapper.includeComments )
		{
			buff ~= "/**";
			foreach ( line; doc.splitLines() )
				buff ~= " * "~ line.strip();
			buff ~= " */";
		}

		if ( name[0].isNumber && name !in wrapper.aliasses )
			buff ~= "_"~ name.toUpper() ~" = "~ value ~",";
		else
			buff ~= tokenToGtkD(name.toUpper(), wrapper.aliasses, false) ~" = "~ value ~",";

		return buff;
	}
}
