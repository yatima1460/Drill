import core.stdc.stdio : printf;

import std.array : join;
import std.stdio : writeln, readln, stderr;
import std.path : dirName, buildNormalizedPath, absolutePath;
import std.getopt : getopt, defaultGetoptPrinter, config, GetOptException;
import std.file : thisExePath;

import FileInfo : FileInfo;
import Crawler : Crawler, CrawlerCallback;
import std.path : buildPath;
import Config : DrillConfig, loadData;
import Context : DrillContext, startCrawling;
import Meta : VERSION, GITHUB_URL;
import std.experimental.logger;

// TODO: capture Ctrl-C and close crawlers?

import core.atomic : atomicOp;

@safe  void resultsFoundWithDate(const(FileInfo) result, void* userObject)
{
    synchronized
    {
        writeln(result.dateModifiedString, "\t", result.fullPath);
    }
}

@safe  void resultsFoundWithSize(const(FileInfo) result, void* userObject)
{
    synchronized
    {
        writeln(result.sizeString, "\t", result.fullPath);
    }
}

@safe  void resultsFoundWithSizeAndDate(const(FileInfo) result, void* userObject)
{
    synchronized
    {
        writeln(result.dateModifiedString, "\t", result.sizeString, "\t", result.fullPath);
    }
}

// import core.sync.mutex;

// shared Mutex mtx;
// static this()
// {
//     mtx = new shared Mutex();
// }

struct DrillCLI
{

    int number = -1;
    DrillContext context;

    @safe void resultsFoundBare(const(FileInfo) result, void* userObject)
    //in(context !is null)
    {

        synchronized
        {
             
            // mtx.lock_nothrow();
            if (number == 0)
            {
                context.stopCrawlingSync();
                return;
            }
            number--;

            writeln(result.fullPath);

            // mtx.unlock_nothrow();

        }
    }
 import core.stdc.stdlib : exit;
    this(string[] args)
    {

       

        try
        {
            DrillConfig data = loadData(dirName(thisExePath));

            bool date = false;
            bool size = false;

            auto opt = getopt(args, config.bundling, config.passThrough,
                    "date|d", "Show results date", &date, "size|s",
                    "Show results size", &size, "number|n", "Max results", &number);

            if (opt.helpWanted)
            {
                writeln("Drill CLI v" ~ VERSION ~ " - " ~ GITHUB_URL);
                writeln("Example use: drill-cli -ds \"foobar\"");
                defaultGetoptPrinter("Options:", opt.options);
                exit(0);
            }

            switch (args.length)
            {

                // What even is POSIX
            case 0:
                stderr.writeln(
                        "Your operating system does not pass the executable path as first argument");
                exit(1);
                break;

                // No search string
            case 1:
                writeln("Drill CLI v" ~ VERSION ~ " - " ~ GITHUB_URL);
                writeln("Pass a string as an argument for Drill to search");
                writeln("Example use: drill-cli -ds \"foobar\"");
                defaultGetoptPrinter("Options:", opt.options);
                exit(0);
                break;

                // Search string provided
            case 2:
                CrawlerCallback[bool][bool] printCallback;
                printCallback[false][false] = &resultsFoundBare;
                // printCallback[false][true] = &resultsFoundWithDate;
                // printCallback[true][false] = &resultsFoundWithSize;
                // printCallback[true][true] = &resultsFoundWithSizeAndDate;

                context = startCrawling(data, args[1], printCallback[size][date], null);
                context.waitForCrawlers();

                info("Drill CLI finished cleanly");
                exit(0);
                break;

                // More unnecessary arguments
            default:
                stderr.writeln("Oops, you gave more arguments than expected.");
                exit(1);
                break;

            }
        }
        catch (GetOptException e)
        {
            stderr.writefln("Error processing command line arguments: %s", e.msg);
            exit(1);
           
        }
        catch (Exception e)
        {
            stderr.writefln("Generic unknown error: %s", e.msg);
            exit(1);
            
        }

    }

}

int main(string[] args)
{
    DrillCLI cli = DrillCLI(args);



    import core.memory : GC;

    
    GC.addRoot(&cli);
    return 0;
}
