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

module gtd.GirWrapper;

import std.algorithm;
import std.array;
import std.file;
import std.uni;
import std.path;
import std.stdio;
import std.string;

import gtd.DefReader;
import gtd.GirField;
import gtd.GirFunction;
import gtd.GirPackage;
import gtd.GirStruct;
import gtd.GirType;
import gtd.GirVersion;
import gtd.GlibTypes;
import gtd.IndentedStringBuilder;
import gtd.Log;

enum PrintFileMethod
{
	Absolute,
	Relative,
	Default
}

class GirWrapper
{
	bool includeComments = true;
	bool useRuntimeLinker;
	bool useBindDir;

	bool printFiles;
	PrintFileMethod printFileMethod = PrintFileMethod.Default;
	string cwdOrBaseDirectory;

	string inputDir;
	string outputDir;
	string srcDir = "./";
	string commandlineGirPath;

	static string licence;
	static string[string] aliasses;

	static GirPackage[string] packages;

	public this(string inputDir, string outputDir)
	{
		this.inputDir         = inputDir;
		this.outputDir       = outputDir;
	}

	void proccess(string lookupFileName)
	{
		if ( !exists(buildPath(inputDir, lookupFileName)) )
			error(lookupFileName, " not found, check '--help' for more information.");

		DefReader defReader = new DefReader( buildPath(inputDir, lookupFileName) );

		proccess(defReader);
	}

	void proccess(DefReader defReader, GirPackage currentPackage = null, bool isDependency = false, GirStruct currentStruct = null)
	{
		while ( !defReader.empty )
		{
			if ( !currentPackage && defReader.key.among(
					"addAliases", "addConstants", "addEnums", "addFuncts", "addStructs", "file", "move",
					"struct", "class", "interface", "namespace", "noAlias", "noConstant", "noEnum", "noCallback") )
				error("Found: '", defReader.key, "' before wrap.", defReader);

			if ( !currentStruct && defReader.key.among(
					"code", "cType", "extend", "implements", "import", "interfaceCode", "merge",
					"noCode", "noExternal", "noProperty", "noSignal", "noStruct", "override", "structWrap",
					"array", "in", "out", "inout", "ref") )
				error("Found: '", defReader.key, "' without an active struct.", defReader);

			switch ( defReader.key )
			{
				//Toplevel keys.
				case "bindDir":
					warning("Don't use bindDir, it is no longer used since the c definitions have moved.", defReader);
					break;
				case "includeComments":
					includeComments = defReader.valueBool;
					break;
				case "inputRoot":
					warning("Don't use inputRoot, it has been removed as it was never implemented.", defReader);
					break;
				case "license":
					licence = defReader.readBlock().join();
					break;
				case "outputRoot":
					if ( outputDir == "./out" )
						outputDir = defReader.value;
					break;

				//Global keys.
				case "alias":
					if ( currentStruct )
						loadAA(currentStruct.aliases, defReader);
					else
						loadAA(aliasses, defReader);
					break;
				case "copy":
					try
						copyFiles(inputDir, buildPath(outputDir, srcDir), defReader.value);
					catch(FileException ex)
						error(ex.msg, defReader);
					break;
				case "dependency":
					loadDependency(defReader);
					break;
				case "lookup":
					DefReader reader = new DefReader( buildPath(inputDir, defReader.value) );

					proccess(reader, currentPackage, isDependency, currentStruct);
					break;
				case "srcDir":
					srcDir = defReader.value;
					break;
				case "version":
					if ( defReader.value == "end" )
						break;

					if ( defReader.subKey.empty )
						error("No version specified.", defReader);

					bool parseVersion = checkOsVersion(defReader.subKey);

					if ( !parseVersion && defReader.subKey[0].isNumber() )
					{
						if ( !currentPackage )
							error("Only use OS versions before wrap.", defReader);
						parseVersion = defReader.subKey <= currentPackage._version;
					}

					if ( defReader.value == "start" )
					{
						if ( parseVersion )
							break;

						defReader.skipBlock();
					}

					if ( !parseVersion )
						break;

					size_t index = defReader.value.indexOf(':');
					defReader.key = defReader.value[0 .. max(index, 0)].strip();
					defReader.value = defReader.value[index +1 .. $].strip();

					if ( !defReader.key.empty )
						continue;

					break;
				case "wrap":
					if ( isDependency )
					{
						currentPackage.name = defReader.value;
						break;
					}

					if ( outputDir.empty )
						error("Found wrap while outputRoot isn't set", defReader);
					if (defReader.value in packages)
						error("Package '", defReader.value, "' is already defined.", defReader);

					currentStruct = null;
					currentPackage = new GirPackage(defReader.value, this, srcDir);
					packages[defReader.value] = currentPackage;
					break;

				//Package keys
				case "addAliases":
					currentPackage.lookupAliases ~= defReader.readBlock();
					break;
				case "addConstants":
					currentPackage.lookupConstants ~= defReader.readBlock();
					break;
				case "addEnums":
					currentPackage.lookupEnums ~= defReader.readBlock();
					break;
				case "addFuncts":
					currentPackage.lookupFuncts ~= defReader.readBlock();
					break;
				case "addStructs":
					currentPackage.lookupStructs ~= defReader.readBlock();
					break;
				case "file":
					if ( !isAbsolute(defReader.value) )
					{
						currentPackage.parseGIR(getAbsoluteGirPath(defReader.value));
					}
					else
					{
						warning("Don't use absolute paths for specifying gir files.", defReader);

						currentPackage.parseGIR(defReader.value);
					}
					break;
				case "move":
					string[] vals = defReader.value.split();
					if ( vals.length <= 1 )
						error("No destination for move: ", defReader.value, defReader);
					string newFuncName = ( vals.length == 3 ) ? vals[2] : vals[0];
					GirStruct dest = currentPackage.getStruct(vals[1]);
					if ( dest is null )
						dest = createClass(currentPackage, vals[1]);

					if ( currentStruct && vals[0] in currentStruct.functions )
					{
						currentStruct.functions[vals[0]].strct = dest;
						dest.functions[newFuncName] = currentStruct.functions[vals[0]];
						dest.functions[newFuncName].name = newFuncName;
						if ( newFuncName.startsWith("new") )
							dest.functions[newFuncName].type = GirFunctionType.Constructor;
						if ( currentStruct.virtualFunctions.canFind(vals[0]) )
							dest.virtualFunctions ~= newFuncName;
						currentStruct.functions.remove(vals[0]);
					}
					else if ( vals[0] in currentPackage.collectedFunctions )
					{
						currentPackage.collectedFunctions[vals[0]].strct = dest;
						dest.functions[newFuncName] = currentPackage.collectedFunctions[vals[0]];
						dest.functions[newFuncName].name = newFuncName;
						currentPackage.collectedFunctions.remove(vals[0]);
					}
					else
						error("Unknown function ", vals[0], defReader);
					break;
				case "noAlias":
					currentPackage.collectedAliases.remove(defReader.value);
					break;
				case "noConstant":
					currentPackage.collectedConstants.remove(defReader.value);
					break;
				case "noEnum":
					currentPackage.collectedEnums.remove(defReader.value);
					break;
				case "noCallback":
					currentPackage.collectedCallbacks.remove(defReader.value);
					break;
				case "struct":
					if ( defReader.value.empty )
					{
						currentStruct = null;
					}
					else
					{
						currentStruct = currentPackage.getStruct(defReader.value);
						if ( currentStruct is null )
							currentStruct = createClass(currentPackage, defReader.value);
					}
					break;

				//Struct keys.
				case "array":
					string[] vals = defReader.value.split();

					if ( vals[0] in currentStruct.functions )
					{
						GirFunction func = currentStruct.functions[vals[0]];

						if ( vals[1] == "Return" )
						{
							if ( vals.length < 3 )
							{
								func.returnType.zeroTerminated = true;
								break;
							}

							GirType elementType = new GirType(this);

							elementType.name = func.returnType.name;
							elementType.cType = func.returnType.cType[0..$-1];
							func.returnType.elementType = elementType;
							func.returnType.girArray = true;

							foreach( i, p; func.params )
							{
								if ( p.name == vals[2] )
									func.returnType.length = cast(int)i;
							}
						}
						else
						{
							GirParam param = findParam(currentStruct, vals[0], vals[1]);
							GirType elementType = new GirType(this);

							elementType.name = param.type.name;
							elementType.cType = param.type.cType[0..$-1];
							param.type.elementType = elementType;
							param.type.girArray = true;

							if ( vals.length < 3 )
							{
								param.type.zeroTerminated = true;
								break;
							}

							if ( vals[2] == "Return" )
							{
								param.type.length = -2;
								break;
							}

							foreach( i, p; func.params )
							{
								if ( p.name == vals[2] )
									param.type.length = cast(int)i;
							}
						}
					}
					else if ( currentStruct.fields.map!(a => a.name).canFind(vals[0]) )
					{
						GirField arrayField;
						int lengthID = -1;

						foreach ( int i, field; currentStruct.fields )
						{
							if ( field.name == vals[0] )
								arrayField = field;
							else if ( field.name == vals[1] )
								lengthID = i;

							if ( arrayField && lengthID > -1 )
								break;
						}

						arrayField.type.length = lengthID;
						currentStruct.fields[lengthID].isLength = true;

						GirType elementType = new GirType(this);
						elementType.name = arrayField.type.name;
						elementType.cType = arrayField.type.cType[0..$-1];
						arrayField.type.elementType = elementType;
						arrayField.type.girArray = true;
					}
					else
					{
						error("Field or function: `", vals[0], "' is unknown.", defReader);
					}
					break;
				case "class":
					if ( currentStruct is null )
						currentStruct = createClass(currentPackage, defReader.value);

					currentStruct.lookupClass = true;
					currentStruct.name = defReader.value;
					break;
				case "code":
					currentStruct.lookupCode ~= defReader.readBlock;
					break;
				case "cType":
					currentStruct.cType = defReader.value;
					break;
				case "extend":
					currentStruct.lookupParent = true;
					currentStruct.parent = defReader.value;
					break;
				case "implements":
					if ( defReader.value.empty )
						currentStruct.implements = null;
					else
						currentStruct.implements ~= defReader.value;
					break;
				case "import":
					currentStruct.imports ~= defReader.value;
					break;
				case "interface":
					if ( currentStruct is null )
						currentStruct = createClass(currentPackage, defReader.value);

					currentStruct.lookupInterface = true;
					currentStruct.name = defReader.value;
					break;
				case "interfaceCode":
					currentStruct.lookupInterfaceCode ~= defReader.readBlock;
					break;
				case "merge":
					GirStruct mergeStruct = currentPackage.getStruct(defReader.value);
					currentStruct.merge(mergeStruct);
					GirStruct copy = currentStruct.dup();
					copy.noCode = true;
					copy.noExternal = true;
					mergeStruct.pack.collectedStructs[defReader.value] = copy;
					break;
				case "namespace":
					currentStruct.type = GirStructType.Record;
					currentStruct.lookupClass = false;
					currentStruct.lookupInterface = false;

					if ( defReader.value.empty )
					{
						currentStruct.noNamespace = true;
					}
					else
					{
						currentStruct.noNamespace = false;
						currentStruct.name = defReader.value;
					}
					break;
				case "noCode":
					if ( defReader.valueBool )
					{
						currentStruct.noCode = true;
						break;
					}
					if ( defReader.value !in currentStruct.functions )
						error("Unknown function ", defReader.value, defReader);

					currentStruct.functions[defReader.value].noCode = true;
					break;
				case "noExternal":
					currentStruct.noExternal = true;
					break;
				case "noProperty":
					foreach ( field; currentStruct.fields )
					{
						if ( field.name == defReader.value )
						{
							field.noProperty = true;
							break;
						}
						else if ( field == currentStruct.fields.back )
							error("Unknown field ", defReader.value, defReader);
					}
					break;
				case "noSignal":
					currentStruct.functions[defReader.value~"-signal"].noCode = true;
					break;
				case "noStruct":
					currentStruct.noDecleration = true;
					break;
				case "structWrap":
					loadAA(currentStruct.structWrap, defReader);
					break;

				//Function keys
				case "in":
					string[] vals = defReader.value.split();
					if ( vals[0] !in currentStruct.functions )
						error("Unknown function ", vals[0], defReader);
					findParam(currentStruct, vals[0], vals[1]).direction = GirParamDirection.Default;
					break;
				case "out":
					string[] vals = defReader.value.split();
					if ( vals[0] !in currentStruct.functions )
						error("Unknown function ", vals[0], defReader);
					findParam(currentStruct, vals[0], vals[1]).direction = GirParamDirection.Out;
					break;
				case "override":
					currentStruct.functions[defReader.value].lookupOverride = true;
					break;
				case "inout":
				case "ref":
					string[] vals = defReader.value.split();
					if ( vals[0] !in currentStruct.functions )
						error("Unknown function ", vals[0], defReader);
					findParam(currentStruct, vals[0], vals[1]).direction = GirParamDirection.InOut;
					break;

				default:
					error("Unknown key: ", defReader.key, defReader);
			}

			defReader.popFront();
		}
	}

	void proccessGIR(string girFile)
	{
		GirPackage pack = new GirPackage("", this, srcDir);

		if ( !isAbsolute(girFile) )
		{
			girFile = getAbsoluteGirPath(girFile);
		}

		pack.parseGIR(girFile);
		packages[pack.name] = pack;
	}

	void printFreeFunctions()
	{
		foreach ( pack; packages )
		{
			foreach ( func; pack.collectedFunctions )
			{
				if ( func.movedTo.empty )
					writefln("%s: %s", pack.name, func.name);
			}
		}
	}

	void writeFile(string fileName, string contents, bool createDirectory = false)
	{
		if ( createDirectory )
		{
			try
			{
				if ( !exists(fileName.dirName()) )
					mkdirRecurse(fileName.dirName());
			}
			catch (FileException ex)
			{
				error("Failed to create directory: ", ex.msg);
			}
		}

		std.file.write(fileName, contents);

		if ( printFiles )
			printFilePath(fileName);
	}

	string getAbsoluteGirPath(string girFile)
	{
		if ( commandlineGirPath )
		{
			string cmdGirFile = buildNormalizedPath(commandlineGirPath, girFile);

			if ( exists(cmdGirFile) )
				return cmdGirFile;
		}

		return buildNormalizedPath(getGirDirectory(), girFile);
	}

	private void printFilePath(string fileName)
	{
		with (PrintFileMethod) switch(printFileMethod)
		{
			case Absolute:
				writeln(asAbsolutePath(fileName));
				break;
			case Relative:
				writeln(asRelativePath(asAbsolutePath(fileName), cwdOrBaseDirectory));
				break;
			default:
				writeln(fileName);
				break;
		}
	}

	private string getGirDirectory()
	{
		version(Windows)
		{
			import std.process : environment;

			static string path;

			if (path !is null)
				return path;

			foreach (p; splitter(environment.get("PATH"), ';'))
			{
				string dllPath = buildNormalizedPath(p, "libgtk-3-0.dll");

				if ( exists(dllPath) )
					path = p.buildNormalizedPath("../share/gir-1.0");
			}

			return path;
		}
		else version(OSX)
		{
			import std.process : environment;

			static string path;

			if (path !is null)
				return path;

			path = environment.get("GTK_BASEPATH");
			if(path)
			{
				path = path.buildNormalizedPath("../share/gir-1.0");
			}
			else
			{
				path = environment.get("HOMEBREW_ROOT");
				if(path)
				{
					path = path.buildNormalizedPath("share/gir-1.0");
				}
			}

			return path;
		}
		else
		{
			return "/usr/share/gir-1.0";
		}
	}

	private GirParam findParam(GirStruct strct, string func, string name)
	{
		foreach( param; strct.functions[func].params )
		{
			if ( param.name == name )
				return param;
		}

		return null;
	}

	private void loadAA (ref string[string] aa, const DefReader defReader)
	{
		string[] vals = defReader.value.split();

		if ( vals.length == 1 )
			vals ~= "";

		if ( vals.length == 2 )
			aa[vals[0]] = vals[1];
		else
			error("Worng amount of arguments for key: ", defReader.key, defReader);
	}

	private void loadDependency(DefReader defReader)
	{
		if ( defReader.value == "end" )
			return;

		if ( defReader.subKey.empty )
			error("No dependency specified.", defReader);

		GirInclude inc = GirPackage.includes.get(defReader.subKey, GirInclude.init);

		if ( defReader.value == "skip" )
			inc.skip = true;
		else if ( defReader.value == "start" )
		{
			inc.lookupFile = defReader.fileName;
			inc.lookupLine = defReader.lineNumber;

			inc.lookupText = defReader.readBlock();
		}
		else
			error("Missing 'skip' or 'start' for dependency: ", defReader.subKey, defReader);

		GirPackage.includes[defReader.subKey] = inc;
	}

	private void copyFiles(string srcDir, string destDir, string file)
	{
		string from = buildNormalizedPath(srcDir, file);
		string to = buildNormalizedPath(destDir, file);

		if ( !printFiles )
			writefln("copying file [%s] to [%s]", from, to);

		if ( isFile(from) )
		{
			if ( printFiles )
				writeln(to);

			copy(from, to);
			return;
		}

		void copyDir(string from, string to)
		{
			if ( !exists(to) )
				mkdirRecurse(to);

			foreach ( entry; dirEntries(from, SpanMode.shallow) )
			{
				string dst = buildPath(to, entry.name.baseName);

				if ( isDir(entry.name) )
				{
					copyDir(entry.name, dst);
				}
				else
				{
					if ( printFiles && !dst.endsWith("functions-runtime.d") && !dst.endsWith("functions-compiletime.d") )
						printFilePath(dst);
						
					copy(entry.name, dst);
				}
			}
		}

		copyDir(from, to);

		if ( file == "cairo" )
		{
			if ( printFiles )
				printFilePath(buildNormalizedPath(to, "c", "functions.d"));

			if ( useRuntimeLinker )
				copy(buildNormalizedPath(to, "c", "functions-runtime.d"), buildNormalizedPath(to, "c", "functions.d"));
			else
				copy(buildNormalizedPath(to, "c", "functions-compiletime.d"), buildNormalizedPath(to, "c", "functions.d"));

			remove(buildNormalizedPath(to, "c", "functions-runtime.d"));
			remove(buildNormalizedPath(to, "c", "functions-compiletime.d"));
		}
	}

	private GirStruct createClass(GirPackage pack, string name)
	{
		GirStruct strct = new GirStruct(this, pack);
		strct.name = name;
		strct.cType = pack.cTypePrefix ~ name;
		strct.type = GirStructType.Record;
		strct.noDecleration = true;
		pack.collectedStructs["lookup"~name] = strct;

		return strct;
	}

	private bool checkOsVersion(string _version)
	{
		if ( _version.empty || !(_version[0].isAlpha() || _version[0] == '!') )
			return false;

		version(Windows)
		{
			return _version.among("Windows", "!OSX", "!linux", "!Linux", "!Posix") != 0;
		}
		else version(OSX)
		{
			return _version.among("!Windows", "OSX", "!linux", "!Linux", "Posix") != 0;
		}
		else version(linux)
		{
			return _version.among("!Windows", "!OSX", "linux", "Linux", "Posix") != 0;
		}
		else version(Posix)
		{
			return _version.among("!Windows", "!OSX", "!linux", "!Linux", "Posix") != 0;
		}
		else
		{
			return false;
		}
	}

}

/**
 * Apply aliasses to the tokens in the string, and
 * camelCase underscore separated tokens.
 */
string stringToGtkD(string str, string[string] aliases, bool caseConvert = true)
{
	return stringToGtkD(str, aliases, null, caseConvert);
}

string stringToGtkD(string str, string[string] aliases, string[string] localAliases, bool caseConvert = true)
{
	size_t pos, start;
	string seps = " \n\r\t\f\v()[]*,;";
	auto converted = appender!string();

	while ( pos < str.length )
	{
		if ( !seps.canFind(str[pos]) )
		{
			start = pos;

			while ( pos < str.length && !seps.canFind(str[pos]) )
				pos++;

			//Workaround for the tm struct, type and variable have the same name.
			if ( pos < str.length && str[pos] == '*' && str[start..pos] == "tm" )
				converted.put("void");
			else
				converted.put(tokenToGtkD(str[start..pos], aliases, localAliases, caseConvert));

			if ( pos == str.length )
				break;
		}

		converted.put(str[pos]);
		pos++;
	}

	return converted.data;
}

unittest
{
	assert(stringToGtkD("token", ["token":"tok"]) == "tok");
	assert(stringToGtkD("string token_to_gtkD(string token, string[string] aliases)", ["token":"tok"])
	       == "string tokenToGtkD(string tok, string[string] aliases)");
}

string tokenToGtkD(string token, string[string] aliases, bool caseConvert=true)
{
	return tokenToGtkD(token, aliases, null, caseConvert);
}

string tokenToGtkD(string token, string[string] aliases, string[string] localAliases, bool caseConvert=true)
{
	if ( token in glibTypes )
		return glibTypes[token];
	else if ( token in localAliases )
		return localAliases[token];
	else if ( token in aliases )
		return aliases[token];
	else if ( token.startsWith("cairo_") && token.endsWith("_t", "_t*", "_t**") )
		return token;
	else if ( token == "pid_t" )
		return token;
	else if ( caseConvert )
		return tokenToGtkD(removeUnderscore(token), aliases, localAliases, false);
	else
		return token;
}

string removeUnderscore(string token)
{
	char pc;
	auto converted = appender!string();

	while ( !token.empty )
	{
		if ( token[0] == '_' )
		{
			pc = token[0];
			token = token[1..$];

			continue;
		}

		if ( pc == '_' )
			converted.put(token[0].toUpper());
		else
			converted.put(token[0]);

		pc = token[0];
		token = token[1..$];
	}

	return converted.data;
}

unittest
{
	assert(removeUnderscore("this_is_a_test") == "thisIsATest");
}
