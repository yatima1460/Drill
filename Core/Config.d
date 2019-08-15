import std.path : buildPath, dirName, expandTilde;
import std.file : thisExePath;
import std.regex: Regex;
import std.conv : to;
import std.algorithm : canFind;
import std.array : replace;
import std.algorithm, std.stdio, std.string;
import std.array : array;
import std.experimental.logger;
import std.algorithm : filter;
import std.array : array, split;
import std.file : dirEntries, SpanMode, DirEntry, readText, FileException;
import std.path : baseName;
import std.path : stripExtension;
import std.path : buildPath;
import std.conv: to;
import std.experimental.logger;
import std.regex: Regex, regex;
import std.algorithm : canFind, filter, map;
import std.array : array;

import Utils : mergeAllTextFilesInDirectory;
import Utils : getMountpoints;
import Meta : VERSION;
// immutable(string) DEFAULT_BLOCK_LIST    = import("BlockLists.txt");
// immutable(string) DEFAULT_PRIORITY_LIST = import("PriorityLists.txt");

// TODO: load and save config in ~/.config


@safe @nogc pure struct DrillConfig
{
    string ASSETS_DIRECTORY;
    invariant
    {
        assert(ASSETS_DIRECTORY !is null);
        assert(ASSETS_DIRECTORY.length > 0);
    }
    string[] BLOCK_LIST;
    string[] PRIORITY_LIST;

    
    Regex!char[] PRIORITY_LIST_REGEX;
    invariant
    {
        assert(PRIORITY_LIST_REGEX.length == PRIORITY_LIST.length);
    }
    bool singlethread;

   
string[string] mime;
  
    
}

version (linux)
{
    /**
Returns the path where the config data is stored
*/
    @safe public string getConfigPath()
    {

        return expandTilde("~/.config/drill-search");

    }
}

// private void createDefaultConfigFiles()
// {
//     import std.path : buildPath;
//     import std.file : write; 
//     import std.array : join;
//     import std.path : baseName;

//     write(buildPath(getConfigPath(),"BlockList.txt"), DEFAULT_BLOCK_LIST); 
//     write(buildPath(getConfigPath(),"PriorityList.txt"), DEFAULT_PRIORITY_LIST); 
// }





// do not add "private" so we support old compilers
pure nothrow @safe char[] cleanLines(char[] x)
{
   
    char[] s = x;
    while (s.canFind("  ")) 
        s = s.replace("  "," ");
    return s;
}

// string[] loadBlocklists()
// {

// }

// TODO: do this at compile time?
string[string] loadMime()
{
       
    auto file = File(buildPath(dirName(thisExePath),"mime.types")); 


    char[][] lines = file.byLine()
                        .filter!(x => !x.canFind("#"))
                        .map!strip
                        .map!(x => x.replace("/","-"))
                        .map!(x => x.replace("\t"," "))
                        .map!cleanLines
                        // .map!(x =>  x.split(" "))
                        .array
                        ;            // Read lines
                        //   .map!split           // Split into words
                        //   .map!(a => a.length) // Count words per line
                        //   .sum();              // Total word count


    string[string] icons;


    
    // icons = lines.map!(x => x.split(" ").filter!(x => x.length > 0)).array;

  
    foreach(line; lines)
    {
        auto splitted = line.split(" ");
        if (splitted.length == 0) continue;
        for(int i = 1; i < splitted.length; i++)
        {
            icons[to!string(splitted[i])] = to!string(splitted[0]);
        }
    }


    version (GTK)
    {

    
        auto assoc = dirEntries(buildPath(dirName(thisExePath),"IconsFallback"),"*.txt", SpanMode.shallow, false); 

        foreach (fileFallback; assoc)
        {
            //writeln("fileFallback ",fileFallback," => ",assoc," assoc.");
            auto fileAssoc = File(fileFallback); 
            auto iconsFileAssoc = fileAssoc.byLine();
            foreach (extName; iconsFileAssoc)
            {
                string extWithoutDot = to!string(extName.replace(".",""));
                if (icons.get(extWithoutDot,null) == null)
                {
                   
                    icons[extWithoutDot] = baseName(stripExtension(fileFallback.name));
                }
            }


        }


        foreach(key,value;icons)
        {
            info("Extension '",key,"' => '",value,"' icon.");
        }
    }


    return icons;
}
/*
Loads Drill data to be used in any crawling
*/
DrillConfig loadData(immutable(string) assetsDirectory)
{
   
    
    //Logger.logDebug("DrillAPI " ~ VERSION);
    //Logger.logDebug("Mount points found: "~to!string(getMountpoints()));
    auto blockListsFullPath = buildPath(assetsDirectory,"BlockLists");

    info("Assets Directory: " ~ assetsDirectory);
    info("blockListsFullPath: " ~ blockListsFullPath);

    string[] BLOCK_LIST; 
    try
    {
        BLOCK_LIST = mergeAllTextFilesInDirectory(blockListsFullPath);
    }
    catch (FileException fe)
    {
        error(fe.msg);
        error("Error when trying to load block lists, will default to an empty list");
    }

    string[] PRIORITY_LIST;



    Regex!char[] PRIORITY_LIST_REGEX;
    try
    {
        PRIORITY_LIST = mergeAllTextFilesInDirectory(buildPath(assetsDirectory,"PriorityLists"));

       
        PRIORITY_LIST_REGEX = PRIORITY_LIST[].map!(x => regex(x)).array;
    }
    catch (FileException fe)
    {
        error(fe.msg);
        error("Error when trying to read priority lists, will default to an empty list");
    }


    
    
        auto mime = loadMime();

            // DrillConfig dd;
        DrillConfig dd = {
            assetsDirectory,
            BLOCK_LIST,
            PRIORITY_LIST,
            PRIORITY_LIST_REGEX,
            false,
            mime
        };
         return dd;



   
}