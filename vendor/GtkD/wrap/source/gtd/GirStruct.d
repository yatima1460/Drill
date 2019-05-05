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

module gtd.GirStruct;

import std.algorithm: among, sort, uniq, startsWith, endsWith, canFind;
import std.array : replace;
import std.conv;
import std.file : write;
import std.path: buildNormalizedPath;
import std.uni: toUpper, toLower;
import std.range;
import std.string: capitalize, splitLines, strip, chomp;

import gtd.GirConstant;
import gtd.GirField;
import gtd.GirFunction;
import gtd.GirPackage;
import gtd.GirType;
import gtd.GirVersion;
import gtd.GirWrapper;
import gtd.IndentedStringBuilder;
import gtd.LinkedHasMap: Map = LinkedHashMap;
import gtd.Log;
import gtd.XMLReader;

enum GirStructType : string
{
	Class = "class",
	Interface = "interface",
	Record = "record",
	Union = "union"
}

final class GirStruct
{
	string name;
	GirStructType type;
	string doc;
	string cType;
	string parent;
	string libVersion;

	bool lookupClass = false;
	bool lookupInterface = false;
	bool lookupParent = false;  /// is the parent set with the lookup file.
	bool noCode = false;        /// Only generate the C declarations.
	bool noDecleration = false; /// Don't generate a Declaration of the C struct.
	bool noExternal = false;    /// Don't generate a Declaration of the C struct. And don't generate the C function declarations.
	bool noNamespace = false;   /// Generate the functions as global functions.
	string[string] structWrap;
	string[string] aliases;
	string[] lookupCode;
	string[] lookupInterfaceCode;

	string[] implements;
	string[] imports;
	GirField[] fields;
	string[] virtualFunctions;
	Map!(string, GirFunction) functions;
	bool disguised = false;

	GirWrapper wrapper;
	GirPackage pack;

	private GirStruct parentStruct;

	this(GirWrapper wrapper, GirPackage pack)
	{
		this.wrapper = wrapper;
		this.pack = pack;
	}

	GirStruct dup()
	{
		GirStruct copy = new GirStruct(wrapper, pack);

		foreach ( i, field; this.tupleof )
			copy.tupleof[i] = field;

		return copy;
	}

	void parse(T)(XMLReader!T reader)
	{
		name = reader.front.attributes["name"];
		type = cast(GirStructType)reader.front.value;

		if ( "c:type" in reader.front.attributes )
			cType = reader.front.attributes["c:type"];
		else if ( "glib:type-name" in reader.front.attributes )
			cType = reader.front.attributes["glib:type-name"];

		if ( "parent" in reader.front.attributes )
			parent = reader.front.attributes["parent"];
		if ( "version" in reader.front.attributes )
		{
			libVersion = reader.front.attributes["version"];
			pack.checkVersion(libVersion);
		}

		if ( !parent.empty )
		{
			if ( parent == "GObject.InitiallyUnowned" )
				parent = "GObject.Object";
			else if ( parent == "InitiallyUnowned" )
				parent = "Object";
		}

		if ( pack && pack.name != "glib" && "glib:get-type" in reader.front.attributes && reader.front.attributes["glib:get-type"].endsWith("_get_type") )
			functions["get_type"] = getTypeFunction(reader.front.attributes["glib:get-type"]);
		if ( auto disg = "disguised" in reader.front.attributes )
			disguised = *disg == "1";

		if ( reader.front.type == XMLNodeType.EmptyTag )
			return;

		reader.popFront();

		while( !reader.empty && !reader.endTag("class", "interface", "record", "union") )
		{
			switch(reader.front.value)
			{
				case "attribute":
					//TODO: Do we need these attibutes?
					//dbus.name ccode.ordering deprecated replacement.
					reader.skipTag();
					break;
				case "constant":
					GirConstant constant = new GirConstant(wrapper, pack);
					constant.parse(reader);
					pack.collectedConstants[constant.name] = constant;
					constant.name = name.toUpper() ~"_"~ constant.name;
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
				case "field":
					GirField field = new GirField(wrapper);
					field.parse(reader);
					fields ~= field;
					break;
				case "record":
					GirField field = new GirField(wrapper);
					GirStruct strct = new GirStruct(wrapper, null);
					strct.parse(reader);
					strct.cType = strct.cType.toUpper()[0..1] ~ strct.cType[1 .. $];
					field.gtkStruct = strct;
					fields ~= field;
					break;
				case "union":
					GirField field = new GirField(wrapper);
					GirUnion uni = new GirUnion(wrapper);
					uni.parse(reader);
					field.gtkUnion = uni;
					fields ~= field;
					break;
				case "callback":
					GirFunction callback = new GirFunction(wrapper, null);
					callback.parse(reader);
					pack.collectedCallbacks[callback.name] = callback;
					callback.name = name.toUpper() ~ callback.name;
					break;
				case "constructor":
				case "method":
				case "glib:signal":
					if ( type == GirStructType.Record )
						type = GirStructType.Class;
					goto case "function";
				case "function":
					GirFunction func = new GirFunction(wrapper, this);
					func.parse(reader);
					if ( func.type == GirFunctionType.Signal )
						functions[func.name~"-signal"] = func;
					else
						functions[func.name] = func;
					break;
				case "virtual-method":
					// Virtual methods in the gir file are mirrored
					// as regular methods, so we only collect whitch are virtual;
					virtualFunctions ~= reader.front.attributes["name"];
					reader.skipTag();
					break;
				case "implements":
					implements ~= reader.front.attributes["name"];
					break;
				case "prerequisite": // Determines whitch base class the implementor of an interface must implement.
				case "property":
					reader.skipTag();
					break;
				default:
					error("Unexpected tag: ", reader.front.value, " in GirStruct: ", name, reader);
			}

			reader.popFront();
		}

		foreach( func; virtualFunctions )
		{
			if ( auto vFunc = func in functions )
				vFunc.virtual = true;
		}

		if ( type == GirStructType.Union )
		{
			GirField field = new GirField(wrapper);
			GirUnion uni = new GirUnion(wrapper);
			uni.fields = fields;
			field.gtkUnion = uni;
			fields = [field];

			//special case for "_Value__data__union"
			if ( cType.empty )
				cType = name;

			type = GirStructType.Record;

			foreach ( funct; functions )
			{
				if ( funct.type != GirFunctionType.Function )
					type = GirStructType.Class;
			}
		}
	}

	GirStruct getParent()
	{
		if ( !parentStruct )
			parentStruct = pack.getStruct(parent);

		return parentStruct;
	}

	string[] getStructDeclaration()
	{
		if ( noExternal || cType.empty )
			return null;

		string[] buff;

		if ( doc !is null && wrapper.includeComments && type == GirStructType.Record )
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

		if ( !fields.empty )
		{
			buff ~= "struct "~ tokenToGtkD(cType, wrapper.aliasses, false);
			buff ~= "{";
			buff ~= GirField.getFieldDeclarations(fields, wrapper);
			buff ~= "}";
		}
		else
		{
			buff ~= "struct "~ tokenToGtkD(cType, wrapper.aliasses, false) ~";";
		}

		return buff;
	}

	void writeClass()
	{
		if ( noCode )
			return;

		if ( type == GirStructType.Record && !(lookupClass || lookupInterface) && (functions.empty && lookupCode.empty ) )
			return;

		parentStruct = pack.getStruct(parent);
		resolveImports();

		if ( type == GirStructType.Record && !(lookupClass || lookupInterface) && !("get_type" in functions && isSimpleStruct()) )
		{
			writeDStruct();
			return;
		}

		if ( isInterface() )
			writeInterface();

		string buff = wrapper.licence;
		auto indenter = new IndentedStringBuilder();

		if ( isInterface() )
			buff ~= "module "~ pack.name ~"."~ name ~"T;\n\n";
		else
			buff ~= "module "~ pack.name ~"."~ name ~";\n\n";

		writeImports(buff, isInterface() );
		writeDocs(buff);

		if ( isInterface() )
			buff ~= "public template "~ name ~"T(TStruct)";
		else if ( isSimpleStruct() )
			buff ~= "public final class "~ name;
		else
			buff ~= "public class "~ name;

		if ( lookupParent && !parentStruct )
			buff ~= " : "~ parent;
		else if ( parentStruct && parentStruct.name != name )
			buff ~= " : "~ parentStruct.name;
		else if ( parentStruct )
			buff ~= " : "~ parentStruct.pack.name.capitalize() ~ parentStruct.name;

		bool first = !parentStruct;

		foreach ( interf; implements )
		{
			if ( parentStruct && parentStruct.implements.canFind(interf) )
				continue;

			// If the parentStruct is in an different package compare without package name.
			if ( parentStruct && interf.canFind(".") && parentStruct.implements.canFind(interf.split('.')[1]) )
				continue;

			GirStruct strct = pack.getStruct(interf);

			if ( strct && first )
			{
				buff ~= " :";
				first = false;
			}
			else if ( strct )
				buff ~= ",";

			if ( strct )
				buff ~= " "~ strct.name ~"IF";
		}

		buff ~= "\n";
		buff ~= indenter.format("{");

		if ( !cType.empty )
		{
			if ( !isInterface() )
			{
				buff ~= indenter.format("/** the main Gtk struct */");
				buff ~= indenter.format("protected "~ cType ~"* "~ getHandleVar() ~";");

				if ( !parentStruct )
				{
					buff ~= indenter.format("protected bool ownedRef;");
				}
																																												
				buff ~= "\n";
			}
			buff ~= indenter.format("/** Get the main Gtk struct */");
			buff ~= indenter.format("public "~ cType ~"* "~ getHandleFunc() ~"(bool transferOwnership = false)");
			buff ~= indenter.format("{");
			buff ~= indenter.format("if (transferOwnership)");
			buff ~= indenter.format("ownedRef = false;");

			if ( isInterface() )
				buff ~= indenter.format("return cast("~ cType ~"*)getStruct();");
			else
				buff ~= indenter.format("return "~ getHandleVar ~";");

			buff ~= indenter.format("}");
			buff ~= "\n";

			if ( !isInterface() )
			{
				buff ~= indenter.format("/** the main Gtk struct as a void* */");

				if ( parentStruct )
					buff ~= indenter.format("protected override void* getStruct()");
				else
					buff ~= indenter.format("protected void* getStruct()");

				buff ~= indenter.format("{");
				buff ~= indenter.format("return cast(void*)"~ getHandleVar ~";");
				buff ~= indenter.format("}");
				buff ~= "\n";
			}

			if ( !isInterface() && !hasDefaultConstructor() )
			{
				buff ~= indenter.format("/**");
				buff ~= indenter.format(" * Sets our main struct and passes it to the parent class.");
				buff ~= indenter.format(" */");
																																												
				buff ~= indenter.format("public this ("~ cType ~"* "~ getHandleVar() ~", bool ownedRef = false)");
				buff ~= indenter.format("{");
				buff ~= indenter.format("this."~ getHandleVar() ~" = "~ getHandleVar() ~";");

				if ( parentStruct )
					buff ~= indenter.format("super(cast("~ parentStruct.cType ~"*)"~ getHandleVar() ~", ownedRef);");
				else
					buff ~= indenter.format("this.ownedRef = ownedRef;");

				buff ~= indenter.format("}");
				buff ~= "\n";

				if ( shouldFree() )
				{
					buff ~= indenter.format("~this ()");
					buff ~= indenter.format("{");

					if ( wrapper.useRuntimeLinker )
						buff ~= indenter.format("if ( Linker.isLoaded(LIBRARY_"~ pack.name.replace(".","").toUpper() ~") && ownedRef )");
					else
						buff ~= indenter.format("if ( ownedRef )");

					if ( "unref" in functions )
						buff ~= indenter.format(functions["unref"].cType ~"("~ getHandleVar ~");");
					else
						buff ~= indenter.format(functions["free"].cType ~"("~ getHandleVar ~");");

					buff ~= indenter.format("}");
					buff ~= "\n";
				}
				else if ( isSimpleStruct() )
				{
					buff ~= indenter.format("~this ()");
					buff ~= indenter.format("{");

					if ( wrapper.useRuntimeLinker )
						buff ~= indenter.format("if ( Linker.isLoaded(LIBRARY_"~ pack.name.replace(".","").toUpper() ~") && ownedRef )");
					else
						buff ~= indenter.format("if ( ownedRef )");

					buff ~= indenter.format("sliceFree("~ getHandleVar ~");");
					buff ~= indenter.format("}");
					buff ~= "\n";
				}
			}

			foreach ( interf; implements )
			{
				if ( parentStruct && parentStruct.implements.canFind(interf) )
					continue;

				if ( parentStruct && interf.canFind(".") && parentStruct.implements.canFind(interf.split('.')[1]) )
					continue;

				GirStruct strct = pack.getStruct(interf);

				if ( strct )
				{
					buff ~= indenter.format("// add the "~ strct.name ~" capabilities");
					buff ~= indenter.format("mixin "~ strct.name ~"T!("~ cType.chomp("*") ~");");
					buff ~= "\n";
				}
			}

		}

		if ( !lookupCode.empty )
		{
			buff ~= indenter.format(lookupCode);
			buff ~= "\n";

			buff ~= indenter.format(["/**", "*/"]);
		}

		if ( isSimpleStruct() )
		{
			foreach( field; fields )
			{
				if ( field.name.startsWith("dummy") )
					continue;

				buff ~= "\n";
				buff ~= indenter.format(field.getProperty(this));
			}
		}

		foreach ( func; functions )
		{
			if ( func.noCode || func.isVariadic() || func.type == GirFunctionType.Callback )
				continue;

			if ( isInterface() && func.type == GirFunctionType.Constructor )
				continue;

			if ( isInterface() && func.isStatic() )
				continue;

			if ( func.type == GirFunctionType.Signal )
			{
				buff ~= "\n";
				buff ~= indenter.format(func.getAddListenerDeclaration());
				buff ~= indenter.format(func.getAddListenerBody());

				foreach ( param; func.params )
				{
					if ( param.type.name.startsWith("Gdk.Event") && param.type.name != "Gdk.Event" )
					{
						buff ~= "\n";
						buff ~= indenter.format(getGenericEventSignal(func));

						break;
					}
				}
			}
			else
			{
				buff ~= "\n";

				if ( func.name.among("delete", "export", "foreach", "union") )
					buff ~= indenter.format("alias "~ func.name[0..$-1] ~" = "~ tokenToGtkD(func.name, wrapper.aliasses) ~";");
				else if ( func.name == "ref" )
					buff ~= indenter.format("alias doref = "~ tokenToGtkD(func.name, wrapper.aliasses) ~";");

				buff ~= indenter.format(func.getDeclaration());
				buff ~= indenter.format("{");
				buff ~= indenter.format(func.getBody());
				buff ~= indenter.format("}");
			}
		}

		buff ~= indenter.format("}");

		if ( isInterface() )
			wrapper.writeFile(buildNormalizedPath(wrapper.outputDir, pack.srcDir, pack.name.replace(".","/"), name ~"T.d"), buff);
		else
			wrapper.writeFile(buildNormalizedPath(wrapper.outputDir, pack.srcDir, pack.name.replace(".","/"), name ~".d"), buff);
	}

	void writeInterface()
	{
		string buff = wrapper.licence;
		auto indenter = new IndentedStringBuilder();

		buff ~= "module "~ pack.name ~"."~ name ~"IF;\n\n";

		writeImports(buff);
		writeDocs(buff);

		buff ~= "public interface "~ name ~"IF";
		buff ~= indenter.format("{");

		if ( cType )
		{
			buff ~= indenter.format("/** Get the main Gtk struct */");
			buff ~= indenter.format("public "~ cType ~"* "~ getHandleFunc() ~"(bool transferOwnership = false);");
			buff ~= "\n";

			buff ~= indenter.format("/** the main Gtk struct as a void* */");
			buff ~= indenter.format("protected void* getStruct();");
			buff ~= "\n";

			if ( !lookupInterfaceCode.empty )
			{
				buff ~= indenter.format(lookupInterfaceCode);
				buff ~= "\n";

				buff ~= indenter.format(["/**", "*/"]);
			}

			foreach ( func; functions )
			{
				if ( func.noCode || func.isVariadic() || func.type == GirFunctionType.Callback || func.type == GirFunctionType.Constructor )
					continue;

				if ( func.type == GirFunctionType.Signal )
				{
					string[] dec = func.getAddListenerDeclaration();
					dec[$-1] ~= ";";

					buff ~= "\n";
					buff ~= indenter.format(dec);
				}
				else if ( !func.isStatic() )
				{
					string[] dec = func.getDeclaration();
					dec[$-1] = dec[$-1].replace("override ", "");
					dec[$-1] ~= ";";

					buff ~= "\n";

					if ( func.name.among("delete", "export", "foreach", "union") )
						buff ~= indenter.format("alias "~ func.name[0..$-1] ~" = "~ tokenToGtkD(func.name, wrapper.aliasses) ~";");

					buff ~= indenter.format(dec);
				}
				else
				{
					buff ~= "\n";
					buff ~= indenter.format(func.getDeclaration());
					buff ~= indenter.format("{");
					buff ~= indenter.format(func.getBody());
					buff ~= indenter.format("}");
				}
			}

			buff ~= indenter.format("}");
		}

		wrapper.writeFile(buildNormalizedPath(wrapper.outputDir, pack.srcDir, pack.name.replace(".","/"), name ~"IF.d"), buff);
	}

	void writeDStruct()
	{
		string buff = wrapper.licence;
		auto indenter = new IndentedStringBuilder();

		buff ~= "module "~ pack.name ~"."~ name ~";\n\n";

		writeImports(buff);
		writeDocs(buff);

		if ( !noNamespace )
		{
			buff ~= "public struct "~ name ~"\n";
			buff ~= indenter.format("{");
		}

		if ( !lookupCode.empty )
		{
			buff ~= indenter.format(lookupCode);
			buff ~= "\n";

			buff ~= indenter.format(["/**", "*/"]);
		}

		foreach ( func; functions )
		{
			if ( func.noCode || func.isVariadic() || !( func.type == GirFunctionType.Function || func.type == GirFunctionType.Method ) )
				continue;

			buff ~= "\n";

			if ( func.name.among("delete", "export", "foreach", "union") )
					buff ~= indenter.format("alias "~ func.name[0..$-1] ~" = "~ tokenToGtkD(func.name, wrapper.aliasses) ~";");

			buff ~= indenter.format(func.getDeclaration());
			buff ~= indenter.format("{");
			buff ~= indenter.format(func.getBody());
			buff ~= indenter.format("}");
		}

		if ( !noNamespace )
			buff ~= indenter.format("}");

		wrapper.writeFile(buildNormalizedPath(wrapper.outputDir, pack.srcDir, pack.name.replace(".","/"), name ~".d"), buff);
	}

	/**
	 * Return the variable name the c type is stored in.
	 */
	string getHandleVar()
	{
		if (cType.length == 0)
			return "";

		string p = to!string(toLower(cType[0]));
		if ( cType.endsWith("_t") )
		{
			return p ~ cType[1 .. $ - 2];
		} else {
			return p ~ cType[1 .. $];
		}
	}

	/**
	 * Returns the name of the function that returns the cType.
	 */
	string getHandleFunc()
	{
		if ( parent && !parentStruct )
			parentStruct = getParent();

		if ( parentStruct && parentStruct.name == name )
			return "get"~ cast(char)pack.name[0].toUpper ~ pack.name[1..$] ~ name ~"Struct";
		else
			return "get"~ name ~"Struct";
	}

	bool isInterface()
	{
		if ( lookupInterface )
			return true;
		if ( lookupClass )
			return false;
		if ( type == GirStructType.Interface )
			return true;

		return false;
	}

	bool isNamespace()
	{
		return type == GirStructType.Record && !(lookupClass || lookupInterface) && !noNamespace;
	}

	void merge(GirStruct mergeStruct)
	{
		foreach ( func; mergeStruct.functions )
		{
			func.strct = this;
			functions[func.name] = func;
		}
	}

	GirStruct getAncestor()
	{
		if ( parent.empty )
			return this;

		if ( !parentStruct )
			parentStruct = pack.getStruct(parent);

		return parentStruct.getAncestor();
	}

	bool hasFunction(string funct)
	{
		if ( funct in functions )
			return true;

		if ( parent.empty )
			return false;

		if ( !parentStruct )
			parentStruct = pack.getStruct(parent);

		if ( !parentStruct )
			return false;

		return parentStruct.hasFunction(funct);
	}

	private bool hasDefaultConstructor()
	{
		foreach ( line; lookupCode )
		{
			//TODO: Whitespace differences?
			if ( line.strip == "public this ("~ cType ~"* "~ getHandleVar() ~", bool ownedRef = false)" )
				return true;
		}

		return false;
	}

	bool shouldFree()
	{
		if ( !parent.empty && parent != "Boxed" )
			return false;
		if ( name.among("Object", "Boxed") )
			return false;

		if ( auto u = "unref" in functions )
		{
			if ( u.noCode == false && u.params.empty )
				return true;
		}

		if ( auto f = "free" in functions )
		{
			if ( f.noCode == false && f.params.empty )
				return true;
		}
		return false;
	}

	bool isSimpleStruct()
	{
		//TODO: don't use this workaround.
		//TODO: For TestLogMsg, GArray and GByteArray implement array properties that are not zero terminated. 
		if ( cType == "PangoAttribute" || cType == "GTestLogMsg" || cType == "GArray" || cType == "GByteArray" || cType == "GtkTreeIter" )
			return false;

		if ( lookupClass || lookupInterface || noDecleration || noNamespace )
			return false;

		if ( disguised || fields.length == 0 )
			return false;

		if ( !fields.empty && fields[0].type )
		{
			// If the first field is wraped as a D class and isn't declared
			// as a pointer we assume its the parent instance.
			GirStruct dStruct = pack.getStruct(fields[0].type.name);
			if ( dStruct && dStruct.isDClass() && !fields[0].type.cType.endsWith("*") )
				return false;
		}

		foreach ( field; fields )
		{
			if ( !field.writable )
				return false;
		}

		return true;
	}

	bool isDClass()
	{
		if ( type.among(GirStructType.Class, GirStructType.Interface) )
			return true;
		if ( type == GirStructType.Record && (lookupClass || lookupInterface) )
			return true;
		if ( "get_type" in functions && isSimpleStruct() )
			return true;

		return false;
	}

	string[] usedNamespaces()
	{
		string[] namespaces;

		string getNamespace(GirType type)
		{
			if ( type.isArray() )
				type = type.elementType;

			if ( type.cType in wrapper.aliasses || type.cType in aliases )
				return null;

			if ( type.name.canFind(".") )
				return type.name.split(".")[0];

			return null;
		}

		if ( parent.canFind(".") )
				namespaces ~= parent.split(".")[0];

		foreach ( func; functions )
		{
			namespaces ~= getNamespace(func.returnType);
			if ( func.instanceParam )
				namespaces ~= getNamespace(func.instanceParam.type);
			foreach ( param; func.params )
				namespaces ~= getNamespace(param.type);
		}

		return namespaces.sort().uniq.array;
	}

	private void resolveImports()
	{
		if ( parentStruct && parentStruct.name != name)
		{
			imports ~= parentStruct.pack.name ~"."~ parentStruct.name;
		}
		else if ( parentStruct )
		{
			string QParent = parentStruct.pack.name.capitalize() ~ parentStruct.name;
			imports ~= parentStruct.pack.name ~"."~ parentStruct.name ~" : "~ QParent ~" = "~ parentStruct.name;
			structWrap[parent] = QParent;
		}

		imports ~= pack.name ~".c.functions";
		imports ~= pack.name ~".c.types";

		//Temporarily import the old bindDir.*types modules for backwards compatibility.
		const string[string] bindDirs = ["atk": "gtkc", "cairo": "gtkc", "gdk": "gtkc", "gdkpixbuf": "gtkc",
			"gio": "gtkc", "glib": "gtkc", "gobject": "gtkc", "gtk": "gtkc", "pango": "gtkc", "gsv": "gsvc",
			"vte": "vtec", "gstinterfaces": "gstreamerc", "gstreamer": "gstreamerc"];

		if ( pack.wrapper.useBindDir )
		{
			if ( auto dir = pack.name in bindDirs )
				imports ~= *dir ~"."~ pack.name ~"types";
		}

		if ( isSimpleStruct() )
			imports ~= "glib.MemorySlice";

		if ( wrapper.useRuntimeLinker && (shouldFree() || isSimpleStruct()) )
			imports ~= "gtkd.Loader";

		if ( isSimpleStruct() )
		{
			foreach ( field; fields ) 
			{
				if ( field.type.name in structWrap || field.type.name in aliases )
					continue;

				GirStruct dType;
				
				if ( field.type.isArray() )
					dType = pack.getStruct(field.type.elementType.name);
				else
					dType = pack.getStruct(field.type.name);

				if ( dType is this )
					continue;
			
				if ( dType && dType.isDClass() )
				{
					if ( !dType.pack.name.among("cairo", "glib", "gthread") )
						imports ~= "gobject.ObjectG";

					if ( dType.type == GirStructType.Interface || dType.lookupInterface )
						imports ~= dType.pack.name ~"."~ dType.name ~"IF";
					else
						imports ~= dType.pack.name ~"."~ dType.name;
				}
				else if ( field.type.isString() || (field.type.isArray() && field.type.elementType.isString())  )
					imports ~= "glib.Str";
			}
		}

		foreach( func; functions )
		{
			if ( func.noCode )
				continue;

			if ( func.throws )
			{
				imports ~= "glib.ErrorG";
				imports ~= "glib.GException";
			}

			void getReturnImport(GirType type)
			{
				if ( type.name in structWrap || type.name in aliases )
					return;

				GirStruct dType = pack.getStruct(type.name);

				if ( dType && dType.isDClass() )
				{
					if ( !dType.pack.name.among("cairo", "glib", "gthread") )
						imports ~= "gobject.ObjectG";

					if ( dType.type == GirStructType.Interface && func.name.startsWith("new") )
						return;

					if ( dType is this && dType.type != GirStructType.Interface )
						return;

					if ( dType.type == GirStructType.Interface || dType.lookupInterface )
						imports ~= dType.pack.name ~"."~ dType.name ~"IF";
					else
						imports ~= dType.pack.name ~"."~ dType.name;
				}
				else if ( type.name.among("utf8", "filename") || type.cType.among("guchar**") )
					imports ~= "glib.Str";
			}

			if ( func.returnType && func.returnType.cType !in structWrap )
			{
				getReturnImport(func.returnType);

				if ( func.returnType.isArray() )
					getReturnImport(func.returnType.elementType);
			}

			void getParamImport(GirType type)
			{
				if ( type.name in structWrap || type.name in aliases )
					return;

				GirStruct dType = pack.getStruct(type.name);

				if ( dType is this )
					return;
			
				if ( func.type == GirFunctionType.Signal && type.name.startsWith("Gdk.Event") )
					imports ~= "gdk.Event";

				if ( dType && dType.isDClass() )
				{
					if ( dType.type == GirStructType.Interface || dType.lookupInterface )
						imports ~= dType.pack.name ~"."~ dType.name ~"IF";
					else
						imports ~= dType.pack.name ~"."~ dType.name;
				}
				else if ( type.isString() || (type.isArray() && type.elementType.isString()) )
					imports ~= "glib.Str";
			}

			foreach ( param; func.params )
			{
				if ( param.type.cType in structWrap )
					continue;

				getParamImport(param.type);

				if ( param.type.elementType )
					getParamImport(param.type.elementType);

				if ( param.direction != GirParamDirection.Default )
					getReturnImport(param.type);

				if ( param.direction == GirParamDirection.Out
						&& !param.type.cType.endsWith("**")
						&& pack.getStruct(param.type.name) !is null
						&& pack.getStruct(param.type.name).isDClass() )
					imports ~= "glib.MemorySlice"; 
			}

			if ( func.type == GirFunctionType.Signal )
			{
				imports ~= "std.algorithm";
				imports ~= "gobject.Signals";
			}

			if ( func.type == GirFunctionType.Constructor )
				imports ~= "glib.ConstructionException";
		}

		foreach ( interf; implements )
		{
			if ( parentStruct && parentStruct.implements.canFind(interf) )
				continue;

			GirStruct strct = pack.getStruct(interf);

			if ( strct )
			{
				imports ~= strct.pack.name ~"."~ strct.name ~"IF";
				imports ~= strct.pack.name ~"."~ strct.name ~"T";
			}
		}

		imports = uniq(sort(imports)).array;
	}

	private void writeImports(ref string buff, bool _public = false)
	{
		foreach ( imp; imports )
		{
			if ( _public || imp.endsWith("types") )
				buff ~= "public  import "~ imp ~";\n";
			else
				buff ~= "private import "~ imp ~";\n";
		}

		buff ~= "\n\n";
	}

	private void writeDocs(ref string buff)
	{
		if ( doc !is null && wrapper.includeComments )
		{
			buff ~= "/**\n";
			foreach ( line; doc.splitLines() )
				buff ~= " * "~ line.strip() ~"\n";

			if ( libVersion )
			{
				buff ~= " *\n * Since: "~ libVersion ~"\n";
			}

			buff ~= " */\n";
		}
		else if ( wrapper.includeComments )
		{
			buff ~= "/** */\n";
		}
	}

	private GirFunction getTypeFunction(string cIdentifier)
	{
		GirType returnType = new GirType(wrapper);
		returnType.name = "GObject.GType";
		returnType.cType = "GType";

		GirFunction func = new GirFunction(wrapper, this);
		func.type = GirFunctionType.Function;
		func.name = "get_type";
		func.cType = cIdentifier;
		func.returnType = returnType;

		return func;
	}

	/**
	 * Get an overload of events that accept an generic Gdk Event
	 * instead of the spesific type listed in the gir files.
	 * 
	 * This for backwards compatibility with the documentation based wrapper.
	 */
	private string[] getGenericEventSignal(GirFunction func)
	{
		GirFunction signal = func.dup();
		string[] buff;
		
		for ( size_t i; i < signal.params.length; i++ )
		{
			if ( signal.params[i].type.name.startsWith("Gdk.Event") )
			{
				GirType eventType = new GirType(wrapper);
				eventType.name = "Gdk.Event";
				
				GirParam newParam = new GirParam(wrapper);
				newParam.name = signal.params[i].name;
				newParam.doc  = signal.params[i].doc;
				newParam.type = eventType;
				
				signal.params[i] = newParam;
				
				break;
			}
		}

		buff ~= signal.getAddListenerDeclaration();
		buff ~= signal.getAddListenerBody();
		
		return buff;
	}
}

final class GirUnion
{
	string name;
	string doc;
	GirField[] fields;

	GirWrapper wrapper;

	this(GirWrapper wrapper)
	{
		this.wrapper = wrapper;
	}

	void parse(T)(XMLReader!T reader)
	{
		if ( "name" in reader.front.attributes )
			name = reader.front.attributes["name"];

		reader.popFront();

		while( !reader.empty && !reader.endTag("union") )
		{
			switch(reader.front.value)
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
				case "field":
					GirField field = new GirField(wrapper);
					field.parse(reader);
					fields ~= field;
					break;
				case "record":
					GirField field = new GirField(wrapper);
					GirStruct strct = new GirStruct(wrapper, null);
					strct.parse(reader);
					strct.cType = strct.cType.toUpper()[0..1] ~ strct.cType[1 .. $];
					field.gtkStruct = strct;
					fields ~= field;
					break;
				default:
					error("Unexpected tag: ", reader.front.value, " in GirUnion: ", name, reader);
			}
			reader.popFront();
		}
	}

	string[] getUnionDeclaration()
	{
		string[] buff;
		if ( doc !is null && wrapper.includeComments )
		{
			buff ~= "/**";
			foreach ( line; doc.splitLines() )
				buff ~= " * "~ line.strip();
			buff ~= " */";
		}

		if ( name )
			buff ~= "union "~ tokenToGtkD(name.toUpper()[0..1] ~ name[1 .. $], wrapper.aliasses);
		else
			buff ~= "union";

		buff ~= "{";
		buff ~= GirField.getFieldDeclarations(fields, wrapper);
		buff ~= "}";

		if ( name )
			buff ~= tokenToGtkD(name.toUpper()[0..1] ~ name[1 .. $], wrapper.aliasses) ~" "~ tokenToGtkD(name.toLower(), wrapper.aliasses) ~";";

		return buff;
	}
}
