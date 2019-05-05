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

module gtd.GirType;

import std.algorithm: among, canFind, startsWith;
import std.array: replace;
import std.conv: to;
import std.range: empty;

import gtd.GirWrapper;
import gtd.XMLReader;

/**
 * Represent sthe type of an field or a parameter.
 */
final class GirType
{
	string name;
	string cType;
	string dType;
	string doc;
	bool constType;

	int size = -1;   /// The size of a fixed size array.
	int length = -1; /// The index of the param representing the length, not counting the instance param.
	bool zeroTerminated;   /// Is this array zero-terminated.
	bool girArray = false; /// The gir file specifies this as an array. Use isArray to check if this is actually an array.
	GirType elementType;   /// The type of the array elements, also set for Glib.List, Glib.SList Glib.Array and GLib.HashTable.
	GirType keyType;       /// The key type of a HashTable;

	GirWrapper wrapper;

	this(GirWrapper wrapper)
	{
		this.wrapper = wrapper;
	}

	void parse(T)(XMLReader!T reader)
	{
		if ( reader.front.value == "array" )
			girArray = true;

		if ( "c:type" in reader.front.attributes )
			cType = reader.front.attributes["c:type"];
		if ( "length" in reader.front.attributes )
			length = to!int(reader.front.attributes["length"]);
		if ( "zero-terminated" in reader.front.attributes )
			zeroTerminated = to!int(reader.front.attributes["zero-terminated"]) == 1;
		if ( "fixed-size" in reader.front.attributes )
			size = to!int(reader.front.attributes["fixed-size"]);
		if ( "name" in reader.front.attributes )
			name = reader.front.attributes["name"];

		if ( cType is null && name is null )
		{
			name = "none";
			cType = "void";
		}

		if ( cType.canFind(" const") || cType.canFind("const ") )
		{
			constType = true;
			fixType();
		}

		if ( cType.canFind("unsigned ") )
		{
			cType = cType.replace("unsigned ", "u");
		}

		cType = cType.replace("volatile ", "");

		if ( cType == "unsigned" )
			cType = name;

		removeInitialyUnowned();

		if ( cType is null && (name == "filename" || name == "utf8") )
			cType = "gchar*";

		if ( reader.front.type == XMLNodeType.EmptyTag )
			return;

		reader.popFront();

		while ( !reader.empty && !reader.endTag("type", "array") )
		{
			if ( elementType )
				keyType = elementType;

			elementType = new GirType(wrapper);
			elementType.parse(reader);

			reader.popFront();
		}

		if ( cType == elementType.cType && !cType.among("void*", "gpointer", "gconstpointer") )
			cType ~= "*";

		if ( isArray() && (cType == "void" || cType.empty) )
			cType = elementType.cType ~"*";
	}

	bool isString()
	{
		if ( cType.startsWith("gchar*", "char*", "const(char)*") )
			return true;
		if ( name.among("utf8", "filename") )
			return true;
		if ( isArray() && elementType.cType.startsWith("gchar", "char", "const(char)") )
			return true;

		return false;
	}

	bool isArray()
	{
		if ( elementType is null )
			return false;

		// The GLib Arrays are in the GIR files as arrays but they shouldn't be wrapped as such.
		if ( name.among("GLib.Array", "Array", "GLib.ByteArray", "ByteArray", "GLib.PtrArray", "PtrArray") )
			return false;

		if ( girArray )
			return true;

		return false;
	}

	private void fixType()
	{
		if ( name == "utf8" && !cType.canFind("**") )
		{
			cType = "const(char)*";
			return;
		}

		cType = cType.replace("const ", "").replace(" const", "");
	}

	private void removeInitialyUnowned()
	{
		if ( name.among("GObject.InitiallyUnowned", "InitiallyUnowned") )
		{
			if ( name == "GObject.InitiallyUnowned" )
				name = "GObject.Object";
			else if ( name == "InitiallyUnowned" )
				name = "Object";

			if ( cType == "GInitiallyUnowned" )
				cType = "GObject";
			else if ( cType == "GInitiallyUnowned*" )
				cType = "GObject*";
		}
		else if ( name.among("GObject.InitiallyUnownedClass", "InitiallyUnownedClass") )
		{
			if ( name == "GObject.InitiallyUnownedClass" )
				name = "GObject.ObjectClass";
			else if ( name == "InitiallyUnownedClass" )
				name = "ObjectClass";

			if ( cType == "GInitiallyUnownedClass" )
				cType = "GObjectClass";
			else if ( cType == "GInitiallyUnownedClass*" )
				cType = "GObjectClass*";
		}
	}
}
