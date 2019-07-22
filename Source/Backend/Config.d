




immutable(string) DEFAULT_BLOCK_LIST    = import("BlockLists.txt");
immutable(string) DEFAULT_PRIORITY_LIST = import("PriorityLists.txt");




struct DrillConfig
{
    immutable(string) ASSETS_DIRECTORY;
    immutable(string[]) BLOCK_LIST;
    immutable(string[]) PRIORITY_LIST;

    import std.regex: Regex;
    const(Regex!char[]) PRIORITY_LIST_REGEX;
    bool singlethread;
}


/**
Returns the path where the config data is stored
*/
public string getConfigPath()
{
    version (linux)
    {
        import std.path : expandTilde;
        return expandTilde("~/.config/drill-search");
    } 

}


private void createDefaultConfigFiles()
{
    import std.path : buildPath;
    import std.file : write; 
    import std.array : join;
    import std.path : baseName;

    write(buildPath(getConfigPath(),"BlockList.txt"), DEFAULT_BLOCK_LIST); 
    write(buildPath(getConfigPath(),"PriorityList.txt"), DEFAULT_PRIORITY_LIST); 
}




// string[] loadBlocklists()
// {

// }


/*
Loads Drill data to be used in any crawling
*/
DrillConfig loadData(immutable(string) assetsDirectory)
{
    import std.path : buildPath;
    import std.conv: to;
    import Logger : Logger;
    import Utils : mergeAllTextFilesInDirectory;
    import std.file : dirEntries, SpanMode, DirEntry, readText, FileException;
    import Utils : getMountpoints;
    import Meta : VERSION;
    import std.regex: Regex, regex;
    import std.algorithm : canFind, filter, map;
    import std.array : array;
    
    Logger.logDebug("DrillAPI " ~ VERSION);
    Logger.logDebug("Mount points found: "~to!string(getMountpoints()));
    auto blockListsFullPath = buildPath(assetsDirectory,"BlockLists");

    Logger.logDebug("Assets Directory: " ~ assetsDirectory);
    Logger.logDebug("blockListsFullPath: " ~ blockListsFullPath);

    string[] BLOCK_LIST; 
    try
    {
        BLOCK_LIST = mergeAllTextFilesInDirectory(blockListsFullPath);
    }
    catch (FileException fe)
    {
        Logger.logError(fe.toString());
        Logger.logError("Error when trying to load block lists, will default to an empty list");
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
        Logger.logError(fe.toString());
        Logger.logError("Error when trying to read priority lists, will default to an empty list");
    }

    DrillConfig dd = {
        assetsDirectory,
        cast(immutable(string[]))BLOCK_LIST,
        cast(immutable(string[]))PRIORITY_LIST,
        PRIORITY_LIST_REGEX
    };
    return dd;
}