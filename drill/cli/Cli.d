

import drill.core.api : DrillAPI;
import std.array : join;
import std.stdio : writeln, readln;
import core.stdc.stdio :printf;

import drill.core.fileinfo : FileInfo;


void resultsFound(immutable(FileInfo) result)
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
    DrillAPI drill = new DrillAPI();

    import std.functional : toDelegate;
    
    if (args.length == 1)
    {
        writeln("Drill CLI - https://github.com/yatima1460/drill");
        writeln(drill.getVersion());
        printf("Mount points: ");
        writeln(drill.getMountPoints());
        drill.startCrawling(searchInput(),toDelegate(&resultsFound));
    }
       
    else if (args.length == 2)
        drill.startCrawling(args[1],toDelegate(&resultsFoundBare));
    else
    {
        writeln("Wrong arguments count.");
        writeln("Just write one \"value to search\" argument.");
        writeln("It can be inside quotes so you can search for multiple tokens.");
        import core.stdc.stdlib : exit;
        exit(-1);
    }
        

    drill.waitForCrawlers();
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
