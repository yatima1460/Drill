module Drill.CLI;

import core.stdc.stdlib : exit;
import core.stdc.stdio :printf;

import std.array : join;
import std.stdio : writeln, readln;

import FileInfo : FileInfo;
import Crawler : Crawler;
import std.path : buildPath;
import API : drill_data, drill_context;
import API : drill_load_data, drill_start_crawling;
import API : DRILL_VERSION, DRILL_GITHUB_URL;

// TODO: capture Ctrl-C and close crawlers?


void resultsFoundWithDate(immutable(FileInfo) result, void* userObject)
{
    synchronized
    {
        writeln(result.dateModifiedString,"\t",result.fullPath);
    }
}


void resultsFoundWithSize(immutable(FileInfo) result, void* userObject)
{
    synchronized
    {
        writeln(result.sizeString,"\t",result.fullPath);
    }
}


void resultsFoundWithSizeAndDate(immutable(FileInfo) result, void* userObject)
{
    synchronized
    {
        writeln(result.dateModifiedString,"\t",result.sizeString,"\t",result.fullPath);
    }
}



void resultsFoundBare(immutable(FileInfo) result, void* userObject)
{
    synchronized
    {
        writeln(result.fullPath);
    }
}


immutable(string) searchInput()
{
    printf("Search for: ");
    string search = readln();
    immutable(string) searchString = search[0 .. search.length-1];
    if (searchString.length == 0)
        return searchInput();
    return searchString;
}


int main(string[] args)
{
    import std.path : dirName, buildNormalizedPath, absolutePath;
    import std.getopt : getopt, defaultGetoptPrinter, config;

    drill_data data = drill_load_data(buildPath(absolutePath(dirName(buildNormalizedPath(args[0]))),"Assets"));

    bool date = false;
    bool size = false;

    auto opt = getopt(args,
        config.bundling,
        config.passThrough,
        "date|d", "Show results date", &date,
        "size|s", "Show results size", &size
    );

    if(opt.helpWanted) 
    {
        writeln("Drill CLI v"~DRILL_VERSION~" - "~DRILL_GITHUB_URL);
        writeln("Example use: drill-cli -ds \"foobar\"");
        defaultGetoptPrinter("Options:", opt.options);
        import core.stdc.stdlib : exit;
        exit(0);
    }

    switch (args.length)
    {
        // What even is POSIX
        case 0:
            writeln("Your operating system does not pass the executable path as first argument");
            exit(-2);
            break;
            
        // No search string
        case 1:
            writeln("Pass a string as an argument for Drill to search");
            writeln("Example use: drill-cli -ds \"foobar\"");
            defaultGetoptPrinter("Options:", opt.options);
            import core.stdc.stdlib : exit;
            exit(-1);
            break;

        // Search string provided
        case 2:
            auto selectedPrint = (date ?
                             (size ? &resultsFoundWithSizeAndDate : &resultsFoundWithDate)
                             :(size ? &resultsFoundWithSize : &resultsFoundBare));
            auto context = drill_start_crawling(data,args[1],*&selectedPrint,null);
            break;

        // More unnecessary arguments
        default:
            writeln("Oops, you gave more arguments than expected.");
            exit(-1);
    }
    return 0;
}
