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

module gtd.GirConstant;

import std.algorithm : among, canFind;
import std.array : replace;
import std.string : splitLines, strip;

import gtd.GirPackage;
import gtd.GirType;
import gtd.GirWrapper;
import gtd.Log;
import gtd.XMLReader;

final class GirConstant
{
	string name;
	string cType;
	string value;
	string doc;

	GirType type;
	GirPackage pack;
	GirWrapper wrapper;

	this(GirWrapper wrapper, GirPackage pack)
	{
		this.wrapper = wrapper;
		this.pack = pack;
	}

	void parse(T)(XMLReader!T reader)
	{
		name = reader.front.attributes["name"];
		value = reader.front.attributes["value"];
		if ( "c:type" in reader.front.attributes )
			cType = reader.front.attributes["c:type"];
		else
			cType = reader.front.attributes["c:identifier"];

		reader.popFront();

		while( !reader.empty && !reader.endTag("constant") )
		{
			switch(reader.front.value)
			{
				case "type":
					type = new GirType(wrapper);
					type.parse(reader);
					break;
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
				default:
					error("Unexpected tag: ", reader.front.value, " in GirConstant: ", name, reader);
			}
			reader.popFront();
		}

		if ( value.canFind("\\") )
			value = value.replace("\\", "\\\\");

		if ( type.cType.among("gint64", "guint64") )
			// See dmd issue 8929 for why we use UL for signed longs. https://issues.dlang.org/show_bug.cgi?id=8929#c7
			value ~= "UL";
	}

	string[] getConstantDeclaration()
	{
		string[] buff;
		if ( doc !is null && wrapper.includeComments )
		{
			buff ~= "/**";
			foreach ( line; doc.splitLines() )
				buff ~= " * "~ line.strip();
			buff ~= " */";
		}

		if ( type.name in pack.collectedAliases && pack.collectedAliases[type.name].baseType.cType.among("gint64", "guint64") )
			value ~= "UL";

		if ( type.isString() )
			buff ~= "enum "~ name ~" = \""~ value ~"\";";
		else
			buff ~= "enum "~ name ~" = "~ value ~";";

		buff ~= "alias "~ cType ~" = "~ name ~";";

		return buff;
	}
}
