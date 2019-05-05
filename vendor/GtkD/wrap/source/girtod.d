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

module girtod;

import std.algorithm: canFind, find, findSkip, startsWith;
import std.array;
import std.file : exists, getcwd, isFile;
import std.getopt;
import std.path;
import std.stdio;
import core.stdc.stdlib;

import gtd.GirWrapper;
import gtd.Log;
import gtd.WrapException;

void main(string[] args)
{
	bool printFree;
	string lookupFile = "APILookup.txt";

	GirWrapper wrapper = new GirWrapper("./", "./out");
	Option printFilesOption;

	wrapper.cwdOrBaseDirectory = getcwd();

	printFilesOption.optLong = "--print-files";
	printFilesOption.help    = "Write a newline separated list of generated files to stdout. Optionally you can pass 'relative[,/base/path] or 'full' to force printing the relative or full paths of the files.";

	auto helpInformation = getopt(
		args,
		std.getopt.config.passThrough,
		"input|i",            "Directory containing the API description. Or a lookup file (Default: ./)", &wrapper.inputDir,
		"output|o",           "Output directory for the generated binding. (Default: ./out)", &wrapper.outputDir,
		"use-runtime-linker", "Link the gtk functions with the runtime linker.", &wrapper.useRuntimeLinker,
		"gir-directory|g",    "Directory to search for gir files before the system directory.", &wrapper.commandlineGirPath,
		"print-free",         "Print functions that don't have a parent module.", &printFree,
		"use-bind-dir",       "Include public imports for the old gtkc package.", &wrapper.useBindDir,
		"version",            "Print the version and exit", (){ writeln("GIR to D ", import("VERSION")); exit(0); }
	);

	if (helpInformation.helpWanted)
	{
		defaultGetoptPrinter("girtod is an utility that generates D bindings using the GObject introspection files.\n\nOptions:",
			helpInformation.options ~ printFilesOption);
		exit(0);
	}

	if ( args.length > 1 )
		handlePrintFiles(args, wrapper);

	if ( wrapper.inputDir.exists && wrapper.inputDir.isFile() )
	{
		lookupFile = wrapper.inputDir.baseName();
		wrapper.inputDir = wrapper.inputDir.dirName();
	}

	try
	{
		//Read in the GIR and API files.
		if ( lookupFile.extension == ".gir" )
			wrapper.proccessGIR(lookupFile);
		else
			wrapper.proccess(lookupFile);

		if ( printFree )
			wrapper.printFreeFunctions();

		//Generate the D binding
		foreach(pack; wrapper.packages)
		{
			if ( pack.name == "cairo" )
				continue;

			if ( wrapper.useRuntimeLinker )
				pack.writeLoaderTable();
			else
				pack.writeExternalFunctions();

			pack.writeTypes();
			pack.writeClasses();
		}
	}
	catch (WrapException ex)
	{
		error(ex);
	}
}

void handlePrintFiles(string[] args, GirWrapper wrapper)
{
	string value;

	args.popFront();

	if ( args.front.startsWith("--print-files") )
	{
		if ( args.front.findSkip("=") )
		{
			value = args.front;
		}

		args.popFront();

		if ( value.empty && !args.empty && !args.front.startsWith("--") )
		{
			value = args.front;
			args.popFront();
		}
	}
	
	if ( !args.empty )
	{
		writeln("Unable to parse parameters: Unrecognized option ", args.front);
		exit(0);
	}

	wrapper.printFiles = true;

	if ( value == "absolute" || value == "full" )
	{
		wrapper.printFileMethod = PrintFileMethod.Absolute;
	}
	else if ( value.startsWith("relative") )
	{
		wrapper.printFileMethod = PrintFileMethod.Relative;

		if ( value.findSkip(",") )
			wrapper.cwdOrBaseDirectory = value;

		if ( !isAbsolute(wrapper.cwdOrBaseDirectory) )
			error("The base directory passed to relative must be absolute.");
	}
	else if ( !value.empty )
	{
		error("Unknown option: '", value, "' for print-files.");
	}
}
