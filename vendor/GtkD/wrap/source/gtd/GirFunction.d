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

module gtd.GirFunction;

import std.algorithm: among, startsWith, endsWith;
import std.conv;
import std.range;
import std.string : chomp, splitLines, strip;
import std.uni: toUpper, toLower;

import gtd.GirEnum;
import gtd.GirStruct;
import gtd.GirType;
import gtd.GirVersion;
import gtd.GirWrapper;
import gtd.Log;
import gtd.XMLReader;

enum GirFunctionType : string
{
	Constructor = "constructor",
	Method = "method",
	Function = "function",
	Callback = "callback",
	Signal = "glib:signal"
}

enum GirTransferOwnership : string
{
	None = "none",          /// Gtk owns the returned reference.
	Full = "full",          /// We own the returned reference.
	Container = "container" /// The container in which the references reside has ownership.
}

final class GirFunction
{
	string name;
	GirFunctionType type;
	string doc;
	string cType;
	string libVersion;
	string movedTo;
	bool virtual = false;
	bool throws = false;
	bool lookupOverride; /// Force marking this function with override.
	bool noCode; /// Don't generate any class code for this function.

	GirType returnType;
	GirTransferOwnership returnOwnership = GirTransferOwnership.None;
	GirParam instanceParam;
	GirParam[] params;

	GirWrapper wrapper;
	GirStruct strct;

	this (GirWrapper wrapper, GirStruct strct)
	{
		this.wrapper = wrapper;
		this.strct = strct;
	}

	GirFunction dup()
	{
		GirFunction copy = new GirFunction(wrapper, strct);
		
		foreach ( i, field; this.tupleof )
			copy.tupleof[i] = field;
		
		return copy;
	}

	void parse(T)(XMLReader!T reader)
	{
		name = reader.front.attributes["name"];
		// Special case for g_iconv wich doesnt have a name.
		if ( name.empty && "moved-to" in reader.front.attributes )
			name = reader.front.attributes["moved-to"];

		type = cast(GirFunctionType)reader.front.value;

		if ( "c:type" in reader.front.attributes )
			cType = reader.front.attributes["c:type"];
		if ( "c:identifier" in reader.front.attributes )
			cType = reader.front.attributes["c:identifier"];
		if ( "version" in reader.front.attributes )
		{
			libVersion = reader.front.attributes["version"];
			if ( strct )
				strct.pack.checkVersion(libVersion);
		}
		if ( "throws" in reader.front.attributes )
			throws = reader.front.attributes["throws"] == "1";
		if ( "moved-to" in reader.front.attributes )
			movedTo = reader.front.attributes["moved-to"];

		reader.popFront();

		while( !reader.empty && !reader.endTag("constructor", "method", "function", "callback", "glib:signal") )
		{
			switch ( reader.front.value )
			{
				case "attribute":
					//TODO: Do we need these attibutes?
					//dbus.name ccode.ordering deprecated replacement.
					reader.skipTag();
					break;
				case "doc":
				case "doc-stability":
					reader.popFront();
					doc ~= reader.front.value;
					reader.popFront();
					break;
				case "doc-deprecated":
					reader.popFront();
					doc ~= "\n\nDeprecated: "~ reader.front.value;
					reader.popFront();
					break;
				case "doc-version":
					reader.skipTag();
					break;
				case "return-value":
					if ( "transfer-ownership" in reader.front.attributes )
						returnOwnership = cast(GirTransferOwnership)reader.front.attributes["transfer-ownership"];

					returnType = new GirType(wrapper);
					reader.popFront();

					while( !reader.empty && !reader.endTag("return-value") )
					{
						switch ( reader.front.value )
						{
							case "doc":
								reader.popFront();
								returnType.doc ~= reader.front.value;
								reader.popFront();
								break;
							case "array":
							case "type":
								returnType.parse(reader);
								break;
							default:
								error("Unexpected tag: ", reader.front.value, " in GirFunction: ", name, reader);
						}
						reader.popFront();
					}
					break;
				case "parameters":
					reader.popFront();
					while( !reader.empty && !reader.endTag("parameters") )
					{
						switch ( reader.front.value )
						{
							case "instance-parameter":
								instanceParam = new GirParam(wrapper);
								instanceParam.parse(reader);
								break;
							case "parameter":
								GirParam param = new GirParam(wrapper);
								param.parse(reader);
								params ~= param;
								break;
							default:
								error("Unexpected tag: ", reader.front.value, " in GirFunction: ", name, reader);
						}
						reader.popFront();
					}
					break;
				default:
					error("Unexpected tag: ", reader.front.value, " in GirFunction: ", name, reader);
			}
			reader.popFront();
		}

		if ( type == GirFunctionType.Function && name.startsWith("new") && returnType.cType != "void" )
			type = GirFunctionType.Constructor;

		// For the case where a param is `const gchar* name[]` whitch ends up in the gir files
		// as an array with elementType name=utf8 c:type=gchar, missing the [].
		switch ( cType )
		{
			case "gtk_icon_theme_choose_icon":
			case "gtk_icon_theme_choose_icon_for_scale":
				params[0].type.cType = "char**";
				params[0].type.elementType.cType = "char*";
				break;
			case "g_object_getv":
			case "g_object_setv":
				params[1].type.cType = "char**";
				params[1].type.elementType.cType = "char*";
				break;
			case "gst_init":
			case "gst_init_check":
				params[1].type.cType = "char***";
				params[1].type.elementType.cType = "char**";
				break;
			case "g_object_new_with_properties":
				params[2].type.cType = "char**";
				params[2].type.elementType.cType = "char*";
				break;
			case "g_key_file_set_locale_string_list":
				params[3].type.cType = "char**";
				params[3].type.elementType.cType = "char*";
				break;
			default: break;
		}
	}

	bool isVariadic()
	{
		if ( params.empty )
			return false;
		else if ( params[$-1].name == "..." )
			return true;

		return false;
	}

	/**
	 * Is this function a static function.
	 */
	bool isStatic()
	{
		if ( strct.noNamespace )
			return false;

		if ( type == GirFunctionType.Function && !(!params.empty && isInstanceParam(params[0])) )
			return true;

		if ( type == GirFunctionType.Method && strct.isNamespace() )
			return true;

		return false;
	}

	string[] getCallbackDeclaration()
	{
		string[] buff;

		writeDocs(buff);
		buff ~= "public alias extern(C) "~ getExternalFunctionType() ~" "~ tokenToGtkD(cType, wrapper.aliasses, localAliases()) ~";";

		return buff;
	}

	string[] getFunctionPointerDecleration()
	{
		string[] buff;

		writeDocs(buff);
		buff ~= "extern(C) "~ getExternalFunctionType() ~" "~ tokenToGtkD(name, wrapper.aliasses, localAliases()) ~";";

		return buff;
	}

	string getLinkerExternal()
	{
		assert(type != GirFunctionType.Callback);
		assert(type != GirFunctionType.Signal);

		if (strct.pack.name == "glgdk")
			return getExternalFunctionType() ~" glc_"~ cType ~";";
		else
			return getExternalFunctionType() ~" c_"~ cType ~";";
	}

	string getExternal()
	{
		assert(type != GirFunctionType.Callback);
		assert(type != GirFunctionType.Signal);

		string ext;
		string type = stringToGtkD(returnType.cType, wrapper.aliasses, localAliases());

		if ( type.startsWith("bool") )
			ext ~= type.replaceFirst("bool", "int");
		else
			ext ~= type;

		ext ~= " "~ cType ~"("~ getExternalParameters() ~");";

		return ext;
	}

	private string getExternalFunctionType()
	{
		string ext;
		string type = stringToGtkD(returnType.cType, wrapper.aliasses, localAliases());

		if ( type.startsWith("bool") )
			ext ~= type.replaceFirst("bool", "int");
		else
			ext ~= type;

		ext ~= " function("~ getExternalParameters() ~")";

		return ext;
	}

	private string getExternalParameters()
	{
		string ext, type;

		if ( instanceParam )
		{
			ext ~= stringToGtkD(instanceParam.type.cType, wrapper.aliasses, localAliases());
			ext ~= " ";
			ext ~= tokenToGtkD(instanceParam.name, wrapper.aliasses, localAliases());
		}

		foreach ( i, param; params )
		{
			if ( i > 0 || instanceParam )
				ext ~= ", ";

			type = stringToGtkD(param.type.cType, wrapper.aliasses, localAliases());

			if ( type.startsWith("bool") )
				ext ~= type.replaceFirst("bool", "int");
			else
				ext ~= type;

			ext ~= " ";
			//Both name and type are ... for Variadic functions.
			if ( param.name != "..." )
				ext ~= tokenToGtkD(param.name, wrapper.aliasses, localAliases());
		}

		if ( throws )
			ext ~= ", GError** err";

		return ext;
	}

	string[] getDeclaration()
	{
		string[] buff;
		string dec = "public ";

		resolveLength();
		writeDocs(buff);

		if ( type == GirFunctionType.Constructor )
		{
			dec ~= "this(";
		}
		else
		{
			if ( isStatic() )
				dec ~= "static ";

			if ( lookupOverride || checkOverride() )
				dec ~= "override ";

			dec ~= getType(returnType) ~" ";
			dec ~= tokenToGtkD(name, wrapper.aliasses, localAliases()) ~"(";
		}

		size_t paramCount;

		if ( instanceParam && ((type == GirFunctionType.Method && (strct.isNamespace() || strct.noNamespace )) || type == GirFunctionType.Constructor) )
		{
			dec ~= getType(instanceParam.type) ~" "~ tokenToGtkD(instanceParam.name, wrapper.aliasses, localAliases());
			paramCount++;
		}

		foreach( param; params )
		{
			if ( param.lengthFor )
				continue;

			if ( returnType.length > -1 && param == params[returnType.length] && params[returnType.length].direction != GirParamDirection.Default )
				continue;

			if ( paramCount == 0 && strct.type == GirStructType.Record && isInstanceParam(param) )
				continue;

			if ( paramCount++ > 0 )
				dec ~= ", ";

			if ( param.direction == GirParamDirection.Out )
				dec ~= "out ";
			else if ( param.direction == GirParamDirection.InOut )
				dec ~= "ref ";

			dec ~= getType(param.type, param.direction) ~" ";
			dec ~= tokenToGtkD(param.name, wrapper.aliasses, localAliases());
		}

		dec ~= ")";
		buff ~= dec;

		return buff;
	}

	string[] getBody()
	{
		string[] buff;
		string[] outToD;
		string gtkCall = cType ~"(";

		GirStruct returnDType;

		if ( returnType.isArray() )
		{
			returnDType = strct.pack.getStruct(returnType.elementType.name);

			if ( returnDType && returnType.elementType.cType.empty )
				returnType.elementType.cType = returnDType.cType ~"*";
		}
		else
		{
			returnDType = strct.pack.getStruct(returnType.name);

			if ( returnDType && returnType.cType.empty )
				returnType.cType = returnDType.cType ~"*";
		}

		if ( instanceParam || ( !params.empty && isInstanceParam(params[0])) )
		{
			GirStruct dType;

			if ( instanceParam )
			{
				dType = strct.pack.getStruct(instanceParam.type.name);

				if ( dType.cType != instanceParam.type.cType.removePtr() && !instanceParam.type.cType.among("gpointer", "gconstpointer") )
					gtkCall ~= "cast("~ stringToGtkD(instanceParam.type.cType, wrapper.aliasses, localAliases()) ~")";
			}
			else
			{
				dType = strct.pack.getStruct(params[0].type.name);

				if ( dType.cType != params[0].type.cType.removePtr() && !params[0].type.cType.among("gpointer", "gconstpointer") )
					gtkCall ~= "cast("~ stringToGtkD(params[0].type.cType, wrapper.aliasses, localAliases()) ~")";
			}

			if ( instanceParam && instanceParam.type.name in strct.structWrap )
			{
				GirStruct insType = strct.pack.getStruct(strct.structWrap[instanceParam.type.name]);

				if ( insType )
					dType = insType;
			}

			if ( type == GirFunctionType.Constructor || strct.isNamespace() || strct.noNamespace )
			{
				string id = tokenToGtkD(instanceParam.name, wrapper.aliasses, localAliases());

				if ( dType && !(dType.isNamespace() || dType.noNamespace) )
					gtkCall ~= "("~ id ~" is null) ? null : "~ id ~"."~ dType.getHandleFunc() ~"()";
				else
					gtkCall ~= id;
			}
			else if ( dType.type == GirStructType.Interface || dType.lookupInterface )
			{
				gtkCall ~= strct.getHandleFunc() ~"()";
			}
			else
			{
				gtkCall ~= strct.getHandleVar();
			}
		}

		foreach( i, param; params )
		{
			GirStruct dType;
			string id = tokenToGtkD(param.name, wrapper.aliasses, localAliases());

			if ( param.type.isArray() )
				dType = strct.pack.getStruct(param.type.elementType.name);
			else if ( auto dStrct = strct.pack.getStruct(strct.structWrap.get(param.type.name, "")) )
				dType = dStrct;
			else
				dType = strct.pack.getStruct(param.type.name);

			if ( i == 0 && isInstanceParam(param) )
				continue;

			if ( instanceParam || i > 0 )
				gtkCall ~= ", ";

			if ( param.type.isString() )
			{
				if ( isStringArray(param.type, param.direction) )
				{
					// out string[], ref string[]
					if ( param.direction != GirParamDirection.Default )
					{
						buff ~= "char** out"~ id ~" = ";

						if ( param.direction == GirParamDirection.Out )
							buff[$-1] ~= "null;";
						else
							buff[$-1] ~= "Str.toStringzArray("~ id ~");";

						string len = lenId(param.type);
						if ( !len.empty )
							len = ", "~ len;

						gtkCall ~= "&out"~ id;
						outToD ~= id ~" = Str.toStringArray(out"~ id ~ len ~");";
					}
					// string[]
					else
					{
						gtkCall ~= "Str.toStringzArray("~ id ~")";
					}
				}
				else
				{
					if ( param.direction != GirParamDirection.Default )
					{
						string len = lenId(param.type);

						// A buffer to fill.
						if ( !param.type.cType.endsWith("**") )
						{
							gtkCall ~= id ~".ptr";

							if ( !len.empty && params[param.type.length].direction != GirParamDirection.Default )
								outToD ~= id ~" = "~ id ~"[0.."~ len ~"];";
						}
						// out string, ref string
						else
						{
							buff ~= "char* out"~ id ~" = ";

							if ( param.direction == GirParamDirection.Out )
								buff[$-1] ~= "null;";
							else
								buff[$-1] ~= "Str.toStringz("~ id ~");";

							if ( !len.empty )
								len = ", "~ len;

							gtkCall ~= "&out"~ id;
							outToD ~= id ~" = Str.toString(out"~ id ~ len ~");";
						}
					}
					// string
					else
					{
						gtkCall ~= "Str.toStringz("~ id ~")";
					}
				}
			}
			else if ( dType && dType.isDClass() )
			{
				if ( param.type.isArray() )
				{
					GirType elementType = param.type.elementType;
					GirStruct dElementType = strct.pack.getStruct(elementType.name);

					if ( elementType.cType.empty )
						elementType.cType = stringToGtkD(param.type.cType, wrapper.aliasses, localAliases())[0 .. $-1];

					// out gtkdType[], ref gtkdType[]
					if ( param.direction != GirParamDirection.Default )
					{
						if ( param.direction == GirParamDirection.Out )
						{
							buff ~= elementType.cType ~" out"~ id ~" = null;";
						}
						else
						{
							if ( !buff.empty )
								buff ~= "";
							buff ~= elementType.cType.removePtr() ~ "**[] inout"~ id ~" = new "~ elementType.cType.removePtr() ~"*["~ id ~".length];";
							buff ~= "for ( int i = 0; i < "~ id ~".length; i++ )";
							buff ~= "{";
							buff ~= "inout"~ id ~"[i] = "~ id~ "[i]."~ dElementType.getHandleFunc() ~"();";
							buff ~= "}";
							buff ~= "";
							buff ~= elementType.cType.removePtr() ~ "** out"~ id ~" = inout"~ id ~".ptr;";
						}

						gtkCall ~= "&out"~ id;

						if ( !outToD.empty )
							outToD ~= "";
						outToD ~= id ~" = new "~ dElementType.name ~"["~ lenId(param.type, "out"~ id) ~"];";
						outToD ~= "for(size_t i = 0; i < "~ lenId(param.type, "out"~ id) ~"; i++)";
						outToD ~= "{";
						if ( elementType.cType.endsWith("**") )
							outToD ~= id ~"[i] = " ~ construct(elementType.name) ~ "(cast(" ~ elementType.cType[0..$-1] ~ ") out"~ id ~"[i]);";
						else
							outToD ~= id ~"[i] = " ~ construct(elementType.name) ~ "(cast(" ~ elementType.cType ~ ") &out"~ id ~"[i]);";
						outToD ~= "}";
					}
					// gtkdType[]
					else
					{
						//TODO: zero-terminated see: g_signal_chain_from_overridden
						if ( !buff.empty )
							buff ~= "";
						buff ~= elementType.cType ~ "[] "~ id ~"Array = new "~ elementType.cType ~"["~ id ~".length];";
						buff ~= "for ( int i = 0; i < "~ id ~".length; i++ )";
						buff ~= "{";
						if ( elementType.cType.endsWith("*") )
							buff ~= id ~"Array[i] = "~ id ~"[i]."~ dElementType.getHandleFunc() ~"();";
						else
							buff ~= id ~"Array[i] = *("~ id ~"[i]."~ dElementType.getHandleFunc() ~"());";
						buff ~= "}";
						buff ~= "";

						gtkCall ~= id ~"Array.ptr";
					}
				}
				else
				{
					// out gtkdType, ref gtkdType
					if ( param.direction != GirParamDirection.Default && param.type.cType.endsWith("**") )
					{
						buff ~= param.type.cType.removePtr() ~"* out"~ id ~" = ";

						if ( param.direction == GirParamDirection.Out )
							buff[$-1] ~= "null;";
						else
							buff[$-1] ~= id ~"."~ dType.getHandleFunc() ~"();";

						gtkCall ~= "&out"~ id;

						outToD ~= id ~" = "~ construct(param.type.name) ~"(out"~ id ~");";
					}
					else if ( param.direction == GirParamDirection.Out )
					{
						buff ~= param.type.cType.removePtr() ~"* out"~ id ~" = sliceNew!"~ param.type.cType.removePtr() ~"();";

						gtkCall ~= "out"~ id;

						outToD ~= id ~" = "~ construct(param.type.name) ~"(out"~ id ~", true);";
					}
					// gtkdType
					else
					{
						gtkCall ~= "("~ id ~" is null) ? null : ";
						if ( dType.cType != param.type.cType.removePtr() && !param.type.cType.among("gpointer", "gconstpointer") )
							gtkCall ~= "cast("~ stringToGtkD(param.type.cType, wrapper.aliasses, localAliases()) ~")";

						if ( param.ownership == GirTransferOwnership.Full && dType.shouldFree() )
							gtkCall ~= id ~"."~ dType.getHandleFunc ~"(true)";
						else
							gtkCall ~= id ~"."~ dType.getHandleFunc ~"()";
					}
				}
			}
			else if ( param.lengthFor || (returnType.length == i && param.direction != GirParamDirection.Default ) )
			{
				string arrId;
				string lenType = tokenToGtkD(param.type.cType.removePtr(), wrapper.aliasses, localAliases());

				if ( param.lengthFor )
					arrId = tokenToGtkD(param.lengthFor.name, wrapper.aliasses, localAliases());

				final switch ( param.direction ) with (GirParamDirection)
				{
					case Default:
						gtkCall ~= "cast("~ lenType ~")"~ arrId ~".length";
						break;
					case Out:
						buff ~= lenType ~" "~ id ~";";
						gtkCall ~= "&"~id;
						break;
					case InOut:
						buff ~= lenType ~" "~ id ~" = cast("~ lenType ~")"~ arrId ~".length;";
						gtkCall ~= "&"~id;
						break;
				}
			}
			else if ( param.type.name.among("bool", "gboolean") || ( param.type.isArray && param.type.elementType.name.among("bool", "gboolean") ) )
			{
				if ( param.type.isArray() )
				{
					// out bool[], ref bool[]
					if ( param.direction != GirParamDirection.Default )
					{
						if ( param.direction == GirParamDirection.Out )
						{
							buff ~= "int* out"~ id ~" = null;";
						}
						else
						{
							if ( !buff.empty )
								buff ~= "";
							buff ~= "int[] inout"~ id ~" = new int["~ id ~".length];";
							buff ~= "for ( int i = 0; i < "~ id ~".length; i++ )";
							buff ~= "{";
							buff ~= "inout"~ id ~"[i] = "~ id~ "[i] ? 1 : 0;";
							buff ~= "}";
							buff ~= "";
							buff ~= "int* out"~ id ~" = inout"~ id ~".ptr;";
						}

						gtkCall ~= "&out"~ id;

						if ( !outToD.empty )
							outToD ~= "";
						outToD ~= id ~" = new bool["~ lenId(param.type, "out"~ id) ~"];";
						outToD ~= "for(size_t i = 0; i < "~ lenId(param.type, "out"~ id) ~"; i++)";
						outToD ~= "{";
						outToD ~= id ~"[i] = out"~ id ~"[i] != 0);";
						outToD ~= "}";
					}
					// bool[]
					else
					{
						if ( !buff.empty )
							buff ~= "";
						buff ~= "int[] "~ id ~"Array = new int["~ id ~".length];";
						buff ~= "for ( int i = 0; i < "~ id ~".length; i++ )";
						buff ~= "{";
						buff ~= id ~"Array[i] = "~ id ~"[i] ? 1 : 0;";
						buff ~= "}";
						buff ~= "";

						gtkCall ~= id ~"Array.ptr";
					}
				}
				else
				{
					// out bool, ref bool
					if ( param.direction != GirParamDirection.Default )
					{
						buff ~= "int out"~ id;

						if ( param.direction == GirParamDirection.Out )
							buff[$-1] ~= ";";
						else
							buff[$-1] ~= " = ("~ id ~" ? 1 : 0);";

						gtkCall ~= "&out"~ id ~"";
						outToD ~= id ~" = (out"~ id ~" == 1);";
					}
					// bool
					else
					{
						gtkCall ~= id;
					}
				}
			}
			else
			{
				if ( param.type.isArray() )
				{
					// out T[], ref T[]
					if ( param.direction != GirParamDirection.Default )
					{
						string outType = param.type.elementType.cType;
						if ( outType.empty )
							outType = param.type.elementType.name ~"*";

						buff ~= stringToGtkD(outType, wrapper.aliasses, localAliases) ~" out"~ id ~" = ";

						if ( param.direction == GirParamDirection.Out )
							buff[$-1] ~= "null;";
						else
							buff[$-1] ~= id ~".ptr";

						if ( param.type.elementType.cType.empty )
							gtkCall ~= "cast("~stringToGtkD(param.type.cType, wrapper.aliasses, localAliases) ~")&out"~ id ~"";
						else
							gtkCall ~= "&out"~ id ~"";

						outToD ~= id ~" = out"~ id ~"[0 .. "~ lenId(param.type, "out"~ id) ~"];";
					}
					// T[]
					else
					{
						gtkCall ~= id ~".ptr";
					}
				}
				else
				{
					if ( param.type.name in strct.structWrap )
					{
						gtkCall ~= "("~ id ~" is null) ? null : "~ id ~".get"~ strct.structWrap[param.type.name] ~"Struct()";
					}
					else
					{
						// out T, ref T
						if ( param.direction != GirParamDirection.Default )
						{
							gtkCall ~= "&"~ id;
						}
						// T
						else
						{
							gtkCall ~= id;
						}
					}
				}
			}
		}

		if ( throws )
		{
			buff ~= "GError* err = null;";
			gtkCall ~= ", &err";
		}

		enum throwGException = [
			"",
			"if (err !is null)",
			"{",
			"throw new GException( new ErrorG(err) );",
			"}"];

		gtkCall ~= ")";

		if ( !buff.empty && buff[$-1] != "" )
			buff ~= "";

		if ( returnType.name == "none" )
		{
			buff ~= gtkCall ~";";

			if ( throws )
			{
				buff ~= throwGException;
			}

			if ( !outToD.empty )
			{
				buff ~= "";
				buff ~= outToD;
			}

			if ( name == "free" && strct && strct.shouldFree() )
			{
				buff ~= "ownedRef = false;";
			}

			return buff;
		}
		else if ( type == GirFunctionType.Constructor )
		{
			buff ~= "auto p = " ~ gtkCall ~";";

			if ( throws )
			{
				buff ~= throwGException;
			}

			buff ~= "";
			buff ~= "if(p is null)";
			buff ~= "{";
			buff ~= "throw new ConstructionException(\"null returned by " ~ name ~ "\");";
			buff ~= "}";
			buff ~= "";

			if ( !outToD.empty )
			{
				buff ~= outToD;
				buff ~= "";
			}

			/*
			 * Casting is needed because some GTK+ functions
			 * can return void pointers or base types.
			 */
			if ( returnOwnership == GirTransferOwnership.Full && strct.getAncestor().name == "ObjectG" )
				buff ~= "this(cast(" ~ strct.cType ~ "*) p, true);";
			else
				buff ~= "this(cast(" ~ strct.cType ~ "*) p);";

			return buff;
		}
		else if ( returnType.isString() )
		{
			if ( outToD.empty && !throws && !(returnOwnership == GirTransferOwnership.Full) )
			{
				if ( isStringArray(returnType) )
					buff ~= "return Str.toStringArray(" ~ gtkCall ~");";
				else
					buff ~= "return Str.toString(" ~ gtkCall ~");";

				return buff;
			}

			buff ~= "auto retStr = "~ gtkCall ~";";

			if ( throws )
			{
				buff ~= throwGException;
			}

			buff ~= "";

			if ( !outToD.empty )
			{
				buff ~= outToD;
				buff ~= "";
			}

			if ( returnOwnership == GirTransferOwnership.Full )
			{
				if ( isStringArray(returnType) )
					buff ~= "scope(exit) Str.freeStringArray(retStr);";
				else
					buff ~= "scope(exit) Str.freeString(retStr);";
			}

			string len = lenId(returnType);
			if ( !len.empty )
				len = ", "~ len;

			if ( isStringArray(returnType) )
				buff ~= "return Str.toStringArray(retStr"~ len ~");";
			else
				buff ~= "return Str.toString(retStr"~ len ~");";

			return buff;
		}
		else if ( returnDType && returnDType.isDClass() )
		{
			buff ~= "auto p = "~ gtkCall ~";";

			if ( throws )
			{
				buff ~= throwGException;
			}

			if ( !outToD.empty )
			{
				buff ~= "";
				buff ~= outToD;
			}

			buff ~= "";
			buff ~= "if(p is null)";
			buff ~= "{";
			buff ~= "return null;";
			buff ~= "}";
			buff ~= "";

			if ( returnType.isArray() )
			{
				buff ~= returnDType.name ~"[] arr = new "~ returnDType.name ~"["~ lenId(returnType) ~"];";
				buff ~= "for(int i = 0; i < "~ lenId(returnType) ~"; i++)";
				buff ~= "{";
				if ( returnType.elementType.cType.endsWith("*") )
					buff ~= "\tarr[i] = "~ construct(returnType.elementType.name) ~"(cast("~ returnType.elementType.cType ~") p[i]);";
				else
					buff ~= "\tarr[i] = "~ construct(returnType.elementType.name) ~"(cast("~ returnType.elementType.cType ~"*) &p[i]);";
				buff ~= "}";
				buff ~= "";
				buff ~= "return arr;";
			}
			else
			{
				if ( returnOwnership == GirTransferOwnership.Full && !(returnDType.pack.name == "cairo") )
					buff ~= "return "~ construct(returnType.name) ~"(cast("~ returnDType.cType ~"*) p, true);";
				else
					buff ~= "return "~ construct(returnType.name) ~"(cast("~ returnDType.cType ~"*) p);";
			}

			return buff;
		}
		else
		{
			if ( returnType.name == "gboolean" )
				gtkCall ~= " != 0";

			if ( !returnType.isArray && outToD.empty && !throws )
			{
				buff ~= "return "~ gtkCall ~";";
				return buff;
			}

			buff ~= "auto p = "~ gtkCall ~";";

			if ( throws )
			{
				buff ~= throwGException;
			}

			if ( !outToD.empty )
			{
				buff ~= "";
				buff ~= outToD;
			}

			buff ~= "";
			if ( returnType.isArray() )
			{
				if ( returnType.elementType.name == "gboolean" )
				{
					buff ~= "bool[] r = new bool["~ lenId(returnType) ~"];";
					buff ~= "for(size_t i = 0; i < "~ lenId(returnType) ~"; i++)";
					buff ~= "{";
					buff ~= "r[i] = p[i] != 0;";
					buff ~= "}";
					buff ~= "return r;";
				}
				else if ( returnType.elementType.cType.empty && returnType.cType[0..$-1] != returnType.elementType.name )
				{
					buff ~= "return cast("~ getType(returnType) ~")p[0 .. "~ lenId(returnType) ~"];";
				}
				else
				{
					buff ~= "return p[0 .. "~ lenId(returnType) ~"];";
				}
			}
			else
				buff ~= "return p;";

			return buff;
		}

		assert(false, "Unexpected function: "~ name);
	}

	string getSignalName()
	{
		assert(type == GirFunctionType.Signal);

		char pc;
		string signalName;

		foreach ( size_t count, char c; name )
		{
			if ( count == 0 && c != '-')
			{
				signalName ~= toUpper(c);
			}
			else
			{
				if ( c!='-' && c!='_' )
				{
					if ( pc=='-' || pc=='_' )
						signalName ~= toUpper(c);
					else
						signalName ~= c;
				}
			}
			pc = c;
		}

		if ( !signalName.among("Event", "MapEvent", "UnmapEvent", "DestroyEvent") &&
		    endsWith(signalName, "Event") )
		{
			signalName = signalName[0..signalName.length-5];
		}

		return signalName;
	}

	string getDelegateDecleration()
	{
		assert(type == GirFunctionType.Signal);

		string buff = getType(returnType) ~ " delegate(";

		foreach ( param; params )
		{
			//TODO: Signals with arrays.
			if ( param.type.cType == "gpointer" && param.type.isArray() )
				buff ~= "void*, ";
			else
				buff ~= getType(param.type) ~ ", ";
		}

		if ( strct.type == GirStructType.Interface )
			buff ~= strct.name ~"IF)";
		else
			buff ~= strct.name ~")";

		return buff;
	}

	string[] getAddListenerDeclaration()
	{
		string[] buff;

		writeDocs(buff);
		buff ~= "gulong addOn"~ getSignalName() ~"("~ getDelegateDecleration() ~" dlg, ConnectFlags connectFlags=cast(ConnectFlags)0)";

		return buff;
	}

	string[] getAddListenerBody()
	{
		string[] buff;

		buff ~= "{";

		if ( strct.hasFunction("add_events") )
		{
			switch ( name )
			{
				case  "button-press-event":      buff ~= "addEvents(EventMask.BUTTON_PRESS_MASK);";      break;
				case  "button-release-event":    buff ~= "addEvents(EventMask.BUTTON_RELEASE_MASK);";    break;
				case  "enter-notify-event":      buff ~= "addEvents(EventMask.ENTER_NOTIFY_MASK);";      break;
				case  "focus-in-event":          buff ~= "addEvents(EventMask.FOCUS_CHANGE_MASK);";      break;
				case  "focus-out-event":         buff ~= "addEvents(EventMask.FOCUS_CHANGE_MASK);";      break;
				case  "key-press-event":         buff ~= "addEvents(EventMask.KEY_PRESS_MASK);";         break;
				case  "key-release-event":       buff ~= "addEvents(EventMask.KEY_RELEASE_MASK);";       break;
				case  "leave-notify-event":      buff ~= "addEvents(EventMask.LEAVE_NOTIFY_MASK);";      break;
				case  "motion-notify-event":     buff ~= "addEvents(EventMask.POINTER_MOTION_MASK);";    break;
				case  "property-notify-event":   buff ~= "addEvents(EventMask.PROPERTY_CHANGE_MASK);";   break;
				case  "proximity-in-event":      buff ~= "addEvents(EventMask.PROXIMITY_IN_MASK);";      break;
				case  "proximity-out-event":     buff ~= "addEvents(EventMask.PROXIMITY_OUT_MASK);";     break;
				case  "scroll-event":            buff ~= "addEvents(EventMask.SCROLL_MASK);";            break;
				case  "visibility-notify-event": buff ~= "addEvents(EventMask.VISIBILITY_NOTIFY_MASK);"; break;

				default: break;
			}
		}

		buff ~= "return Signals.connect(this, \""~ name ~"\", dlg, connectFlags ^ ConnectFlags.SWAPPED);";
		buff ~= "}";

		return buff;
	}

	
	void writeDocs(ref string[] buff)
	{
		if ( (doc || returnType.doc) && wrapper.includeComments )
		{
			buff ~= "/**";
			foreach ( line; doc.splitLines() )
				buff ~= " * "~ line.strip();

			if ( !params.empty || (instanceParam && type == GirFunctionType.Constructor) )
			{
				buff ~= " *";
				buff ~= " * Params:";

				if ( type == GirFunctionType.Constructor && instanceParam && !instanceParam.doc.empty )
				{
					string[] lines = instanceParam.doc.splitLines();
					buff ~= " *     "~ tokenToGtkD(instanceParam.name, wrapper.aliasses, localAliases()) ~" = "~ lines[0];
					foreach( line; lines[1..$] )
						buff ~= " *         "~ line.strip();
				}

				foreach ( param; params )
				{
					if ( param.doc.empty )
						continue;

					if ( param.lengthFor )
						continue;

					if ( returnType.length > -1 && param == params[returnType.length] && params[returnType.length].direction != GirParamDirection.Default )
						continue;

					if ( isInstanceParam(param) )
						continue;

					string[] lines = param.doc.splitLines();
					buff ~= " *     "~ tokenToGtkD(param.name, wrapper.aliasses, localAliases()) ~" = "~ lines[0];
					foreach( line; lines[1..$] )
						buff ~= " *         "~ line.strip();
				}

				if ( buff.endsWith(" * Params:") )
					buff = buff[0 .. $-2];
			}

			if ( returnType.doc )
			{
				string[] lines = returnType.doc.splitLines();
				if ( doc )
					buff ~= " *";
				buff ~= " * Returns: "~ lines[0];

				foreach( line; lines[1..$] )
					buff ~= " *     "~ line.strip();
			}

			if ( libVersion )
			{
				buff ~= " *";
				buff ~= " * Since: "~ libVersion;
			}

			if ( throws || type == GirFunctionType.Constructor )
				buff ~= " *";

			if ( throws )
				buff ~= " * Throws: GException on failure.";

			if ( type == GirFunctionType.Constructor )
				buff ~= " * Throws: ConstructionException GTK+ fails to create the object.";

			buff ~= " */";
		}
		else if ( wrapper.includeComments )
		{
			buff ~= "/** */\n";
		}
	}

	private void resolveLength()
	{
		foreach( param; params )
		{
			if ( param.type.length > -1 )
				params[param.type.length].lengthFor = param;
		}
	}

	private string[string] localAliases()
	{
		if ( strct )
			return strct.aliases;

		return null;
	}

	/**
	 * Get an string representation of the type.
	 */
	private string getType(GirType type, GirParamDirection direction = GirParamDirection.Default)
	{
		if ( type.isString() )
		{
			if ( direction != GirParamDirection.Default && !type.cType.endsWith("**") )
				return "char[]";
			else if ( direction == GirParamDirection.Default && type.cType.endsWith("***") )
				return "string[][]";
			else if ( type.isArray && isStringArray(type.elementType, direction) )
				return getType(type.elementType, direction) ~"[]";
			else if ( isStringArray(type, direction) )
				return "string[]";

			return "string";
		}
		else if ( type.isArray() )
		{
			string size;

			//Special case for GBytes and GVariant.
			if ( type.cType == "gconstpointer" && type.elementType.cType == "gconstpointer" )
				return "void[]";

			if ( type.cType == "guchar*" )
				return "char[]";

			if ( type.size > -1 )
				size = to!string(type.size);

			string elmType = getType(type.elementType, direction);

			if ( elmType == type.cType )
				elmType = elmType[0..$-1];

			return elmType ~"["~ size ~"]";
		}
		else
		{
			if ( type is null || type.name == "none" )
				return "void";
			else if ( type.name in strct.structWrap )
				return strct.structWrap[type.name];
			else if ( type.name == type.cType )
				return stringToGtkD(type.name, wrapper.aliasses, localAliases());

			GirStruct dType = strct.pack.getStruct(type.name);

			if ( dType && dType.isDClass() )
			{
			    if ( dType.type == GirStructType.Interface )
					return dType.name ~"IF";
			    else
			    	return dType.name;
			}
			else if ( type.cType.empty && dType && dType.type == GirStructType.Record )
				return dType.cType ~ "*";
		}

		if ( type.cType.empty )
		{
			if ( auto enum_ = strct.pack.getEnum(type.name) )
				return enum_.cName;

			return stringToGtkD(type.name, wrapper.aliasses, localAliases());
		}

		if ( direction != GirParamDirection.Default )
			return stringToGtkD(type.cType[0..$-1], wrapper.aliasses, localAliases());

		return stringToGtkD(type.cType, wrapper.aliasses, localAliases());
	}

	private bool isStringArray(GirType type, GirParamDirection direction = GirParamDirection.Default)
	{
		if ( direction == GirParamDirection.Default && type.cType.endsWith("**") )
			return true;
		if ( type.elementType is null )
			return false;
		if ( !type.elementType.cType.endsWith("*") )
			return false;
		if ( direction != GirParamDirection.Default && type.cType.among("char**", "gchar**", "guchar**") )
			return false;

		return true;
	}

	private bool isInstanceParam(GirParam param)
	{
		if ( param !is params[0] )
			return false;
		if ( strct is null || strct.type != GirStructType.Record )
			return false;
		if ( !(strct.lookupClass || strct.lookupInterface) )
			return false;
		if ( param.direction != GirParamDirection.Default )
			return false;
		if ( param.lengthFor !is null )
			return false;
		if ( strct.cType is null )
			return false;
		if ( param.type.cType == strct.cType ~"*" )
			return true;

		return false;
	}

	private string lenId(GirType type, string paramName = "p")
	{
		if ( type.length > -1 && params[type.length].direction == GirParamDirection.Default && paramName != "p" )
			return "cast("~ tokenToGtkD(params[type.length].type.cType.removePtr(), wrapper.aliasses, localAliases()) ~")"~ paramName.replaceFirst("out", "") ~".length";
		else if ( type.length > -1 )
			return tokenToGtkD(params[type.length].name, wrapper.aliasses, localAliases());
		//The c function returns the length.
		else if ( type.length == -2 )
			return "p";
		else if ( type.size > -1 )
			return to!string(type.size);

		if ( type.isString() )
			return null;

		return "getArrayLength("~ paramName ~")";
	}

	/**
	 * Check if any of the ancestors contain the function functionName.
	 */
	private bool checkOverride()
	{
		if ( name == "get_type" )
			return false;
		if ( name == "to_string" && params.empty )
			return true;

		GirStruct ancestor = strct.getParent();

		while(ancestor)
		{
			if ( name in ancestor.functions && name !in strct.aliases )
			{
				GirFunction func = ancestor.functions[name];

				if ( !(func.noCode || func.isVariadic() || func.type == GirFunctionType.Callback) && paramsEqual(func) )
					return true;
			}

			ancestor = ancestor.getParent();
		}

		return false;
	}

	/**
	 * Return true if the params of func match the params of this function.
	 */
	private bool paramsEqual(GirFunction func)
	{
		if ( params.length != func.params.length )
			return false;

		foreach ( i, param; params )
		{
			if ( getType(param.type) != getType(func.params[i].type) )
				return false;
		}

		return true;
	}

	private string construct(string type)
	{
		GirStruct dType = strct.pack.getStruct(type);
		debug assert(dType, "Only call construct for valid GtkD types");
		string name = dType.name;

		if ( type in strct.structWrap )
			name = strct.structWrap[type];

		if ( dType.pack.name.among("cairo", "glib", "gthread") )
			return "new "~name;
		else if( dType.type == GirStructType.Interface )
			return "ObjectG.getDObject!("~ name ~"IF)";
		else
			return "ObjectG.getDObject!("~ name ~")";
	}
}

enum GirParamDirection : string
{
	Default = "",
	Out = "out",
	InOut = "inout",
}

final class GirParam
{
	string doc;
	string name;
	GirType type;
	GirTransferOwnership ownership = GirTransferOwnership.None;
	GirParamDirection direction = GirParamDirection.Default;

	GirParam lengthFor;
	GirWrapper wrapper;

	this(GirWrapper wrapper)
	{
		this.wrapper = wrapper;
	}

	void parse(T)(XMLReader!T reader)
	{
		name = reader.front.attributes["name"];

		if ( "transfer-ownership" in reader.front.attributes )
			ownership = cast(GirTransferOwnership)reader.front.attributes["transfer-ownership"];
		if ( "direction" in reader.front.attributes )
			direction = cast(GirParamDirection)reader.front.attributes["direction"];

		reader.popFront();

		while( !reader.empty && !reader.endTag("parameter", "instance-parameter") )
		{
			if ( reader.front.type == XMLNodeType.EndTag )
			{
				reader.popFront();
				continue;
			}

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
				case "array":
				case "type":
					type = new GirType(wrapper);
					type.parse(reader);
					break;
				case "varargs":
					type = new GirType(wrapper);
					type.name = "...";
					type.cType = "...";
					break;
				default:
					error("Unexpected tag: ", reader.front.value, " in GirParam: ", name, reader);
			}

			reader.popFront();
		}

		if ( direction != GirParamDirection.Default && !type.cType.endsWith("*") )
			direction = GirParamDirection.Default;
	}
}

private string removePtr(string cType)
{
	while ( !cType.empty && cType.back == '*' )
		cType.popBack();

	return cType;
}
