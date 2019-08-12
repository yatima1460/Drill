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
import Context : DrillContext, startCrawling, waitForCrawlers;
import Meta : VERSION, GITHUB_URL;

// TODO: capture Ctrl-C and close crawlers?

void resultsFoundWithDate(const(FileInfo) result, void* userObject)
{
    synchronized
    {
        writeln(result.dateModifiedString, "\t", result.fullPath);
    }
}

void resultsFoundWithSize(const(FileInfo) result, void* userObject)
{
    synchronized
    {
        writeln(result.sizeString, "\t", result.fullPath);
    }
}

void resultsFoundWithSizeAndDate(const(FileInfo) result, void* userObject)
{
    synchronized
    {
        writeln(result.dateModifiedString, "\t", result.sizeString, "\t", result.fullPath);
    }
}

void resultsFoundBare(const(FileInfo) result, void* userObject)
{
    synchronized
    {
        writeln(result.fullPath);
    }
}


int main(string[] args)
{
    try
    {
        DrillConfig data = loadData(dirName(thisExePath));

        bool date = false;
        bool size = false;


        auto opt = getopt(
            args, 
            config.bundling, config.passThrough, 
            "date|d", "Show results date", &date, 
            "size|s", "Show results size", &size);

        if (opt.helpWanted)
        {
            writeln("Drill CLI v" ~ VERSION ~ " - " ~ GITHUB_URL);
            writeln("Example use: drill-cli -ds \"foobar\"");
            defaultGetoptPrinter("Options:", opt.options);
            return 0;
        }

        switch (args.length)
        {

            // What even is POSIX
            case 0:
                stderr.writeln("Your operating system does not pass the executable path as first argument");
                return 1;

            // No search string
            case 1:
                writeln("Drill CLI v" ~ VERSION ~ " - " ~ GITHUB_URL);
                writeln("Pass a string as an argument for Drill to search");
                writeln("Example use: drill-cli -ds \"foobar\"");
                defaultGetoptPrinter("Options:", opt.options);
                return 0;

            // Search string provided
            case 2:
                CrawlerCallback[bool][bool] printCallback;
                printCallback[false][false] = &resultsFoundBare;
                printCallback[false][true] = &resultsFoundWithDate;
                printCallback[true][false] = &resultsFoundWithSize;
                printCallback[true][true] = &resultsFoundWithSizeAndDate;
                DrillContext context = startCrawling(data, args[1], printCallback[size][date], null);
                context.threads.waitForCrawlers();
                return 0;

            // More unnecessary arguments
            default:
                stderr.writeln("Oops, you gave more arguments than expected.");
                return 1;

        }
    }
    catch (GetOptException e)
    {
        stderr.writefln("Error processing command line arguments: %s", e.msg);
        return 1;
    }
    catch (Exception e)
    {
        stderr.writefln("Generic unknown error: %s", e.msg);
        return 1;
    }
}
