module Drill.CLI;

import std.array : join;
import std.stdio : writeln, readln;

import core.stdc.stdio :printf;

import FileInfo : FileInfo;
import API : DrillAPI;
import Crawler : Crawler;
import std.path : buildPath;

void resultsFoundWithDate(immutable(FileInfo) result)
{
    synchronized 
    {
        writeln(result.dateModifiedString,"\t",result.fullPath);
    }
}

void resultsFoundWithSize(immutable(FileInfo) result)
{
    synchronized 
    {
        writeln(result.sizeString,"\t",result.fullPath);
    }
}

void resultsFoundWithSizeAndDate(immutable(FileInfo) result)
{
    synchronized 
    {
        writeln(result.dateModifiedString,"\t",result.sizeString,"\t",result.fullPath);
    }
}


void resultsFoundBare(immutable(FileInfo) result)
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

    
    DrillAPI drill = new DrillAPI(buildPath(absolutePath(dirName(buildNormalizedPath(args[0]))),"Assets"));


    bool date = false;
    bool size = false;

    auto opt = getopt(args,
        config.bundling,
        config.passThrough,
        "date|d", "Show results date", &date,
        "size|s", "Show results size", &size
    );

    if(opt.helpWanted){
        writeln("Drill CLI v"~DrillAPI.DRILL_VERSION~" - "~DrillAPI.GITHUB_URL);
        writeln("Example use: drill-cli -ds \"foobar\"");
        defaultGetoptPrinter("Options:", opt.options);
        import core.stdc.stdlib : exit;
        exit(0);
    }

    if (args.length == 1) // No search string
    {
        writeln("Pass a string as an argument for Drill to search");
        writeln("Example use: drill-cli -ds \"foobar\"");
        defaultGetoptPrinter("Options:", opt.options);
        import core.stdc.stdlib : exit;
        exit(-1);
    }
    
    else if (args.length == 2){
        import std.functional : toDelegate;
        auto selectedPrint = (date ? 
                             (size ? &resultsFoundWithSizeAndDate : &resultsFoundWithDate)
                             :(size ? &resultsFoundWithSize : &resultsFoundBare));
        drill.startCrawling(args[1],toDelegate(selectedPrint));
    }

    else{
        writeln("Oops, you gave more arguments than expected.");
        import core.stdc.stdlib : exit;
        exit(-1);
    }
    // import core.memory;
    // GC.disable();

    // std.concurrency.thisTid;
    // auto application = new Application("me.santamorena.drill", GApplicationFlags.FLAGS_NONE);
    // application.addOnActivate(delegate void(GioApplication app) {
    //     new DrillWindow(application);
    // });
    // return application.run(args);
    return 0;
}
