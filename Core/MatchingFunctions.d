module MatchingFunctions;

import core.memory : GC;

import std.file : DirEntry, DirIterator, dirEntries, SpanMode;
import std.path : baseName, dirName, extension;
import std.uni : toLower;
import std.experimental.logger;
import std.array : array, replace;
import std.algorithm : canFind;
import Utils : isTokenizedStringMatchingString;
import std.file : readText, FileException;

alias MatchingFunction = bool function(DirEntry file, const(string) searchString);



string[string] mime;

@safe bool isFileContentMatchingSearchString(DirEntry file, const(string) searchString)
{
    version (GTK)
    {
        if (mime == null) mime = loadMime();
    }
    
   // immutable(string[]) blacklistedExtensions = [".png",".jpg",".mp4",".psd",".lnk",".sai",".exe",".pdf",".mkv",".swf",".msi",".zip"];
    
    try
    {
    
        auto shouldBeScanned = false;


          version (GTK)
        {

        }
       
        //if (allowedExtensions.canFind(extension(file.name)))
        if (!file.isDir() 
            // && file.size < 100*1024*1024 // 100 megabyte,
            && (
                extension(file.name) == ".md" // markdown is not in the RFC standard
                || mime.get(extension(file.name).replace(".",""),"").canFind("text")
            )
           // && !blacklistedExtensions.canFind(extension(file.name))
        ) 
        {
            bool found = false;
            try
            {
                string fileRead = readText!string(file);
                auto fileContent = toLower(fileRead);
                found = fileContent.canFind(toLower(searchString));
            }
            catch(Exception e)
            {
                try
                {
                    wstring fileRead = readText!wstring(file);
                    auto fileContent = toLower(fileRead);
                    found = fileContent.canFind(toLower(searchString));
                }
                catch(Exception e)
                {
                     try
                    {
                        dstring fileRead = readText!dstring(file);
                        auto fileContent = toLower(fileRead);
                        found = fileContent.canFind(toLower(searchString));
                    }
                    catch(Exception e)
                    {
                        warning(e.msg);
                        return false;
                    }
                    return false;
                }
               

            }

            //GC.collect();
            return found;
        }
        return false;
    }
    catch (Exception e)
    {
        critical("Can't find string: '",searchString,"' inside: '",file.name,"', error is: '",e.msg,"'");
        return false;
    }
    
}



/++
    Params:
        searchString = the search string the user wrote in a Drill frontend
        fileName = the complete file name without a fullpath, only the file name after the slash

    Returns:
        true if the file matches the search input

    Complexity:
        O(searchString*fileName)
+/
pure @safe bool isFileNameMatchingSearchString(DirEntry file, const(string) searchString) 
in (searchString != null)
in (searchString.length > 0)
in (file.name != null)
in (file.name.length > 0)
{
    return isTokenizedStringMatchingString(searchString, baseName(file.name));
}

