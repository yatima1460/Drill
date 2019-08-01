


int main(string[] args) 
{
    import std.stdio : writeln;
    writeln(args);
    import std.file : dirEntries, SpanMode, DirEntry, readText, FileException;
    import std.array : array, replace;
    import std.path : baseName, dirName, extension;

    string[] temp_blocklist = [];

    import std.algorithm : filter;
    import std.string : endsWith;

    DirEntry[] blocklists_file;

    try 
    {
        blocklists_file = dirEntries(args[1], SpanMode.shallow, true).filter!(f => f.name.endsWith(".txt")).array;
    }
    catch (FileException e)
    {
        writeln("\n[PRE-BUILD] ERROR: "~e.msg~"\n");
    }
    

    foreach (string partial_blocklist; blocklists_file)
    {
        import std.array : split;
        temp_blocklist ~= readText(partial_blocklist).split("\n");
    }

    // remove empty newlines
    import std.algorithm : filter;
    import std.array : array;


    string[] merged = temp_blocklist.filter!(x => x.length != 0).array;

   
import std.path : buildPath;
    import std.file : write; 

    import std.array : join;

    write(buildPath(args[2],baseName(args[1])~".txt"), join(merged,"\n")); 

    return 0;
}
