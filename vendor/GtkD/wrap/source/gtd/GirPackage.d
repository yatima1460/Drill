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

module gtd.GirPackage;

import std.algorithm;
import std.array : join, replace;
import std.conv;
import std.file;
import std.path : baseName, buildNormalizedPath;
import std.range : array, back, chain, empty;
import std.regex : ctRegex, matchFirst;
import std.stdio;
import std.string : split, splitLines, strip;
import std.uni;

import gtd.DefReader;
import gtd.GirAlias;
import gtd.GirConstant;
import gtd.GirEnum;
import gtd.GirFunction;
import gtd.GirStruct;
import gtd.GirVersion;
import gtd.GirWrapper;
import gtd.GlibTypes;
import gtd.IndentedStringBuilder;
import gtd.LinkedHasMap: Map = LinkedHashMap;
import gtd.Log;
import gtd.XMLReader;

final class GirPackage
{
	string name;
	string cTypePrefix;
	string srcDir;
	GirVersion _version;
	GirWrapper wrapper;

	string[] lookupAliases;     /// Aliases defined in the lookupfile.
	string[] lookupConstants;   /// Constants defined in the lookupfile.
	string[] lookupEnums;       /// Enums defined in the lookupfile.
	string[] lookupFuncts;      /// Functions defined in the lookupfile.
	string[] lookupStructs;     /// Structs defined in the lookupfile.

	static GirPackage[string] namespaces;
	static GirInclude[string] includes;

	string[] libraries;
	Map!(string, GirAlias)    collectedAliases;   /// Aliases defined in the gir file.
	Map!(string, GirFunction) collectedCallbacks;
	Map!(string, GirConstant) collectedConstants;
	Map!(string, GirEnum)     collectedEnums;     /// Enums defined in the gir file.
	Map!(string, GirFunction) collectedFunctions;
	Map!(string, GirStruct)   collectedStructs;
	GirEnum stockIDs;           /// The StockID enum (Deprecated).
	GirEnum gdkKeys;            /// The GdkKey enum.

	public this(string pack, GirWrapper wrapper, string srcDir)
	{
		this.name = pack;
		this.wrapper = wrapper;
		this.srcDir = srcDir;
		this.stockIDs = new GirEnum(wrapper, this);
		this.gdkKeys  = new GirEnum(wrapper, this);

		GirInclude gobject;
		gobject.name = "GObject";
		gobject._version = "2.0";
		includes["GObject"] = gobject;
	}

	void parseGIR(string girFile)
	{
		if ( !exists(girFile) )
			error("GIR file: '", girFile, "' not found.");

		auto reader = new XMLReader!string(readText(girFile), girFile);

		while ( !reader.empty && reader.front.value != "repository" )
			reader.popFront();

		reader.popFront();

		while ( !reader.empty && reader.front.value == "include" )
		{
			string incName = reader.front.attributes["name"];

			GirInclude inc = includes.get(incName, GirInclude.init);
			inc.name = incName;
			inc._version = reader.front.attributes["version"];
			includes[incName] = inc;

			reader.popFront();
		}

		while ( !reader.empty && reader.front.value != "namespace" )
			reader.popFront();

		if ( name.empty )
			name = reader.front.attributes["name"].toLower();

		namespaces[reader.front.attributes["name"]] = this;
		checkVersion(reader.front.attributes["version"]);
		
		if ( "c:identifier-prefixes" in reader.front.attributes )
			cTypePrefix = reader.front.attributes["c:identifier-prefixes"];

		if ( "shared-library" in reader.front.attributes )
		{
			version(Windows)
				libraries ~= reader.front.attributes["shared-library"].split(',').map!(a => a.startsWith("lib")?a:"lib"~a~".dll").array;
			else version(OSX)
				libraries ~= reader.front.attributes["shared-library"].split(',').map!(a => a.baseName.startsWith("lib")?a.baseName:"lib"~a.baseName~".dylib").array;
			else
				libraries ~= reader.front.attributes["shared-library"].split(',').map!(a => a.startsWith("lib")?a:"lib"~a~".so").array;

			libraries = libraries.sort().uniq.array;
		}
		reader.popFront();

		while ( !reader.empty && !reader.endTag("namespace") )
		{
			if ( reader.front.type == XMLNodeType.EndTag )
			{
				reader.popFront();
				continue;
			}

			switch (reader.front.value)
			{
				case "alias":
					GirAlias gtkAlias = new GirAlias(wrapper);
					gtkAlias.parse(reader);

					if ( gtkAlias.cType == "GType" )
						break;

					collectedAliases[gtkAlias.name] = gtkAlias;
					break;
				case "attribute":
					//TODO: Do we need these attibutes?
					//dbus.name ccode.ordering deprecated replacement.
					reader.skipTag();
					break;
				case "glib:boxed":
					reader.skipTag();
					break;
				case "bitfield":
				case "enumeration":
					GirEnum gtkEnum = new GirEnum(wrapper, this);
					gtkEnum.parse(reader);
					collectedEnums[gtkEnum.name] = gtkEnum;
					break;
				case "class":
				case "interface":
				case "record":
				case "union":
					GirStruct gtkStruct = new GirStruct(wrapper, this);
					gtkStruct.parse(reader);

					//Workaround: Dont overwrite the regular pango classes.
					if ( gtkStruct.cType.among("PangoCairoFont", "PangoCairoFontMap") )
						gtkStruct.name = gtkStruct.cType;

					collectedStructs[gtkStruct.name] = gtkStruct;

					//Don't generate classes named Object.
					if ( gtkStruct.name == "Object" )
						gtkStruct.name = "Object"~ cTypePrefix;
					if ( name == "pango" )
						gtkStruct.name = "Pg"~gtkStruct.name;
					break;
				case "callback":
					GirFunction callback = new GirFunction(wrapper, null);
					callback.parse(reader);
					collectedCallbacks[callback.name] = callback;
					break;
				case "constant":
					parseConstant(reader);
					break;
				case "function":
					parseFunction(reader);
					break;
				default:
					error("Unexpected tag: ", reader.front.value, " in GirPackage: ", name, reader);
			}
			reader.popFront();
		}
	}

	void parseConstant(T)(XMLReader!T reader)
	{
		if ( reader.front.attributes["name"].startsWith("STOCK_") )
		{
			GirEnumMember member = GirEnumMember(wrapper);
			member.parse(reader);
			member.name = member.name[6..$];

			stockIDs.members ~= member;
			return;
		}
		else if ( reader.front.attributes["c:type"].startsWith("GDK_KEY_") )
		{
			GirEnumMember member = GirEnumMember(wrapper);
			member.parse(reader);
			member.name = "GDK_"~ member.name[4..$];

			gdkKeys.members ~= member;
			return;
		}
		// The version attribute of the namspace tag is usualy set to MAJOR.0.
		else if ( reader.front.attributes["name"].startsWith("MAJOR_VERSION") )
		{
			_version.major = to!uint(reader.front.attributes["value"]);
		}
		else if ( reader.front.attributes["name"].startsWith("MINOR_VERSION") )
		{
			_version.minor = to!uint(reader.front.attributes["value"]);
		}
		else if ( reader.front.attributes["name"].startsWith("MICRO_VERSION") )
		{
			_version.micro = to!uint(reader.front.attributes["value"]);
		}

		GirConstant constant = new GirConstant(wrapper, this);
		constant.parse(reader);
		collectedConstants[constant.name] = constant;
	}

	void parseFunction(T)(XMLReader!T reader)
	{
		GirFunction funct = new GirFunction(wrapper, null);
		funct.parse(reader);
		collectedFunctions[funct.name] = funct;

		checkVersion(funct.libVersion);
	}

	GirPackage getNamespace(string name)
	{
		if ( name.empty )
			return null;
			
		if ( name !in namespaces )
		{
			if ( auto inc = name in includes )
			{
				if ( inc.skip ) return null;

				namespaces[name] = inc.parse(wrapper, srcDir);
			}
			else
			{
				foreach ( inc; includes.byValue.filter!(inc => inc.name !in namespaces) )
					namespaces[inc.name] = inc.parse(wrapper, srcDir);

				if ( !includes.byValue.filter!(inc => inc.name !in namespaces).empty )
					return getNamespace(name);
				else
					return null;
			}
		}

		return namespaces.get(name, null);
	}

	GirStruct getStruct(string name)
	{
		GirPackage pack = this;

		if ( name.canFind(".") )
		{
			string[] vals = name.split(".");

			if ( !getNamespace(vals[0]) )
				return null;

			pack = namespaces[vals[0]];
			name = vals[1];
		}
		return pack.collectedStructs.get(name, pack.collectedStructs.get("lookup"~name, null));
	}

	GirEnum getEnum(string name)
	{
		GirPackage pack = this;

		if ( name.canFind(".") )
		{
			string[] vals = name.split(".");

			if ( !getNamespace(vals[0]) )
				return null;

			pack = namespaces[vals[0]];
			name = vals[1];
		}
		return pack.collectedEnums.get(name, null);
	}

	void checkVersion(string _version)
	{
		if (this._version < _version)
			this._version = GirVersion(_version);
	}

	void checkVersion(GirVersion _version)
	{
		if (this._version < _version)
			this._version = _version;
	}

	void writeClasses()
	{
		try
		{
			if ( !exists(buildNormalizedPath(wrapper.outputDir, srcDir, name.replace(".","/"))) )
				mkdirRecurse(buildNormalizedPath(wrapper.outputDir, srcDir, name.replace(".","/")));
		}
		catch (FileException ex)
		{
			error("Failed to create directory: ", ex.msg);
		}

		foreach ( strct; collectedStructs )
			strct.writeClass();
	}

	void writeTypes()
	{
		string buff = wrapper.licence;
		auto indenter = new IndentedStringBuilder();

		buff ~= "module "~ name ~".c.types;\n\n";

		buff ~= getTypeImports();

		buff ~= indenter.format(lookupAliases);
		foreach ( a; collectedAliases )
		{
			buff ~= "\n";
			buff ~= indenter.format(a.getAliasDeclaration());
		}

		buff ~= indenter.format(lookupEnums);
		foreach ( e; collectedEnums )
		{
			buff ~= "\n";
			buff ~= indenter.format(e.getEnumDeclaration());
		}

		buff ~= indenter.format(lookupStructs);
		foreach ( s; collectedStructs )
		{
			if ( s.noExternal || s.noDecleration )
				continue;

			buff ~= "\n";
			buff ~= indenter.format(s.getStructDeclaration());
		}

		buff ~= indenter.format(lookupFuncts);
		foreach ( f; collectedCallbacks )
		{
			buff ~= "\n";
			buff ~= indenter.format(f.getCallbackDeclaration());
		}

		buff ~= indenter.format(lookupConstants);
		foreach ( c; collectedConstants )
		{
			buff ~= "\n";
			buff ~= indenter.format(c.getConstantDeclaration());
		}

		if ( stockIDs.members !is null )
		{
			stockIDs.cName = "StockID";
			stockIDs.doc = "StockIds";
			buff ~= "\n";
			buff ~= indenter.format(stockIDs.getEnumDeclaration());
		}

		if ( gdkKeys.members !is null )
			writeGdkKeys();

		wrapper.writeFile(buildNormalizedPath(wrapper.outputDir, srcDir, name.replace(".","/"), "c/types.d"), buff, true);
	}

	void writeGdkKeys()
	{
		string buff = wrapper.licence;

		buff ~= "module "~ name ~".Keysyms;\n\n";

		buff ~= "/**\n";
		buff ~= " * GdkKeysyms.\n";
		buff ~= " */\n";
		buff ~= "public enum GdkKeysyms\n";
		buff ~= "{\n";

		foreach ( member; gdkKeys.members )
		{
			buff ~= "\t"~ tokenToGtkD(member.name, wrapper.aliasses, false) ~" = "~ member.value ~",\n";
		}

		buff ~= "}\n";
		buff ~= "alias Keysyms = GdkKeysyms;\n";

		wrapper.writeFile(buildNormalizedPath(wrapper.outputDir, srcDir, name.replace(".","/"), "Keysyms.d"), buff, true);
	}

	void writeLoaderTable()
	{
		string buff = wrapper.licence;

		buff ~= "module "~ name ~".c.functions;\n\n";
		buff ~= "import std.stdio;\n";
		buff ~= "import "~ name ~".c.types;\n";

		if ( name == "glib" )
			buff ~= "import gobject.c.types;\n";
		if ( name == "gdk" || name == "pango" )
			buff ~= "import cairo.c.types;\n";

		buff ~= "import gtkd.Loader;\n\n";
		buff ~= getLibraries();
		buff ~= "\n\nshared static this()\n{";

		foreach ( strct; collectedStructs )
		{
			if ( strct.functions.empty || strct.noExternal )
				continue;

			buff ~= "\n\t// "~ name ~"."~ strct.name ~"\n\n";

			foreach ( funct; strct.functions )
			{
				if ( funct.type == GirFunctionType.Callback || funct.type == GirFunctionType.Signal || funct.name.empty )
					continue;

				buff ~= "\tLinker.link("~ funct.cType ~", \""~ funct.cType ~"\", LIBRARY_"~ name.replace(".","").toUpper() ~");\n";
			}
		}

		//WORKAROUND: Windows has two functions with different names in the 32 and 64 bit versions.
		if (name == "glib")
		{
			buff ~= "\n\tversion(Win64)\n";
			buff ~= "\t{\n";
			buff ~= "\t\tLinker.link(g_module_name, \"g_module_name_uft8\", LIBRARY_GLIB);\n";
			buff ~= "\t\tLinker.link(g_module_open, \"g_module_open_utf8\", LIBRARY_GLIB);\n";
			buff ~= "\t}\n";
		}

		buff ~= "}\n\n"
			~ "__gshared extern(C)\n"
			~ "{\n";

		foreach ( strct; collectedStructs )
		{
			if ( strct.functions.empty || strct.noExternal )
				continue;

			buff ~= "\n\t// "~ name ~"."~ strct.name ~"\n\n";

			foreach ( funct; strct.functions )
			{
				if ( funct.type == GirFunctionType.Callback || funct.type == GirFunctionType.Signal || funct.name.empty )
					continue;

				buff ~= "\t"~ funct.getLinkerExternal() ~"\n";
			}
		}

		buff ~= "}\n\n";

		foreach ( strct; collectedStructs )
		{
			if ( strct.functions.empty || strct.noExternal )
				continue;

			buff ~= "\n// "~ name ~"."~ strct.name ~"\n\n";

			foreach ( funct; strct.functions )
			{
				if ( funct.type == GirFunctionType.Callback || funct.type == GirFunctionType.Signal || funct.name.empty )
					continue;

				if (name == "glgdk")
					buff ~= "alias glc_"~ funct.cType ~" "~ funct.cType ~";\n";
				else
					buff ~= "alias c_"~ funct.cType ~" "~ funct.cType ~";\n";
			}
		}

		wrapper.writeFile(buildNormalizedPath(wrapper.outputDir, srcDir, name.replace(".","/"), "c", "functions.d"), buff, true);
	}

	void writeExternalFunctions()
	{
		string buff = wrapper.licence;

		buff ~= "module "~ name ~".c.functions;\n\n";
		buff ~= "import std.stdio;\n";
		buff ~= "import "~ name ~".c.types;\n";

		if ( name == "glib" )
			buff ~= "import gobject.c.types;\n";
		if ( name == "gdk" || name == "pango" )
			buff ~= "import cairo.c.types;\n\n";

		buff ~= getLibraries();

		buff ~= "\n\n__gshared extern(C)\n"
			~ "{\n";

		foreach ( strct; collectedStructs )
		{
			if ( strct.functions.empty || strct.noExternal )
				continue;

			buff ~= "\n\t// "~ name ~"."~ strct.name ~"\n\n";

			foreach ( funct; strct.functions )
			{
				if ( funct.type == GirFunctionType.Callback || funct.type == GirFunctionType.Signal || funct.name.empty )
					continue;

				buff ~= "\t"~ funct.getExternal() ~"\n";
			}
		}

		buff ~= "}";

		wrapper.writeFile(buildNormalizedPath(wrapper.outputDir, srcDir, name.replace(".","/"), "c", "functions.d"), buff, true);
	}

	private string getLibraries()
	{
		string lib = "version (Windows)\n\t";
		lib ~= "static immutable LIBRARY_"~ name.replace(".","").toUpper() ~" = ["~ getDllNames() ~"];";
		lib ~= "\nelse version (OSX)\n\t";
		lib ~= "static immutable LIBRARY_"~ name.replace(".","").toUpper() ~" = ["~ getDylibNames() ~"];";
		lib ~= "\nelse\n\t";
		lib ~= "static immutable LIBRARY_"~ name.replace(".","").toUpper() ~" = ["~ getSoNames() ~"];";

		return lib;
	}

	private auto dllRegex = ctRegex!(`([a-z0-9_]+)(-[0-9\.]+)?(-[0-9]+)?\.dll`);
	private auto dylibRegex = ctRegex!(`([a-z0-9_]+)(-[0-9\.]+?)?(\.[0-9]+)?\.dylib`);
	private auto soRegex = ctRegex!(`([a-z0-9_]+)(-[0-9\.]+)?\.so(\.[0-9]+)?`);

	private string getDllNames()
	{
		version (Windows)
		{
			return "\""~ libraries.join("\", \"") ~"\"";
		}
		else version (OSX)
		{
			string libs;

			foreach ( lib; libraries )
			{
				auto match = matchFirst(lib, dylibRegex);

				libs ~= "\""~ match[1];
				if ( !match[2].empty )
					libs ~= "-"~ match[2][1..$];
				if ( !match[3].empty )
					libs ~= "-"~ match[3][1..$];
				libs ~= ".dll\"";

				if ( lib != libraries.back )
					libs ~= ", ";
			}

			return libs;
		}
		else
		{
			string libs;

			foreach ( lib; libraries )
			{
				auto match = matchFirst(lib, soRegex);

				libs ~= "\""~ match[1];
				if ( !match[2].empty )
					libs ~= "-"~ match[2][1..$];
				if ( !match[3].empty )
					libs ~= "-"~ match[3][1..$];
				libs ~= ".dll\"";

				if ( lib != libraries.back )
					libs ~= ", ";
			}

			return libs;
		}
	}

	private string getDylibNames()
	{
		version (Windows)
		{
			string libs;

			foreach ( lib; libraries )
			{
				auto match = matchFirst(lib, dllRegex);

				libs ~= "\""~ match[1];
				if ( !match[2].empty )
					libs ~= "-"~ match[2][1..$];
				if ( !match[3].empty )
					libs ~= "."~ match[3][1..$];
				libs ~= ".dylib\"";

				if ( lib != libraries.back )
					libs ~= ", ";
			}

			return libs;
		}
		else version (OSX)
		{
			return "\""~ libraries.join("\", \"") ~"\"";
		}
		else
		{
			string libs;

			foreach ( lib; libraries )
			{
				auto match = matchFirst(lib, soRegex);

				libs ~= "\""~ match[1];
				if ( !match[2].empty )
					libs ~= "-"~ match[2][1..$];
				if ( !match[3].empty )
					libs ~= "."~ match[3][1..$];
				libs ~= ".dylib\"";

				if ( lib != libraries.back )
					libs ~= ", ";
			}

			return libs;
		}
	}

	private string getSoNames()
	{
		version (Windows)
		{
			string libs;

			foreach ( lib; libraries )
			{
				auto match = matchFirst(lib, dllRegex);

				libs ~= "\""~ match[1];
				if ( !match[2].empty && !match[3].empty )
					libs ~= "-"~ match[2][1..$];
				libs ~= ".so";
				if ( !match[2].empty && match[3].empty )
					libs ~= "."~ match[2][1..$];
				if ( !match[3].empty )
					libs ~= "."~ match[3][1..$];
				libs ~= "\"";

				if ( lib != libraries.back )
					libs ~= ", ";
			}

			return libs;
		}
		else version (OSX)
		{
			string libs;

			foreach ( lib; libraries )
			{
				auto match = matchFirst(lib, dylibRegex);

				libs ~= "\""~ match[1];
				if ( !match[2].empty )
					libs ~= "-"~ match[2][1..$];
				libs ~= ".so";
				if ( !match[3].empty )
					libs ~= "."~ match[3][1..$];
				libs ~= "\"";

				if ( lib != libraries.back )
					libs ~= ", ";
			}

			return libs;
		}
		else
		{
			return "\""~ libraries.join("\", \"") ~"\"";
		}
	}

	private string getTypeImports()
	{
		string imports;
		string[] usedNamespaces;
		string[] packages;

		foreach ( strct; collectedStructs )
		{
			if ( strct.noExternal )
				continue;

			usedNamespaces = chain(usedNamespaces, strct.usedNamespaces()).sort.uniq.array;
		}

		foreach ( ns; usedNamespaces )
		{
			GirPackage pack = getNamespace(ns);

			if ( pack && pack != this && !packages.canFind(pack.name) )
				packages ~= pack.name;
		}

		packages = packages.sort().array;

		foreach ( pack; packages )
		{
			imports ~= "public import "~ pack ~".c.types;\n";
		}

		if ( !imports.empty )
			imports ~= "\n";

		return imports;
	}
}

struct GirInclude
{
	string name;
	string _version;

	bool skip;
	string[] lookupText;
	string lookupFile;
	size_t lookupLine;

	string girFileName()
	{
		return name ~"-"~ _version ~".gir";
	}

	GirPackage parse(GirWrapper wrapper, string srcDir)
	{
		GirPackage inc = new GirPackage(name.toLower, wrapper, srcDir);
		inc.parseGIR(wrapper.getAbsoluteGirPath(girFileName()));

		if ( auto text = name in defaultLookupText )
			wrapper.proccess(new DefReader(*text, "Default rules"), inc, true);

		wrapper.proccess(new DefReader(lookupText, lookupFile, lookupLine), inc, true);

		return inc;
	}
}
