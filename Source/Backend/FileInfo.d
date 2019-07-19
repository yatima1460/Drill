module FileInfo;

/**
FileInfo is a struct filled by the information a crawler found about files matching the search
*/
struct FileInfo
{
    /**
    The original mountpoint used by a crawler that found this file
    */
    immutable(string) originalMountpoint;

    /**
    true if the file is a directory
    */
    immutable(bool) isDirectory;

    /**
    true if the file is a normal file
    */
    immutable(bool) isFile;

    /**
    true if is a symbolic link
    */
    //bool isSymbolic;

    /**
    string of the date modified
    */
    immutable(string) dateModifiedString;

    /***
    the parent folder
    */
    immutable(string) containingFolder;

    /**
    name of the icon to use on the left of the name
    */
    //string iconName;

    /**
    the filename with extension
    */
    immutable(string) fileName;

    /**
    the filename with extension but lower string
    */
    immutable(string) fileNameLower;

    /**
    only the extension with the dot (ex: .png) 
    */
    immutable(string) extension;

    /**
    Complete full path of the file
    */
    immutable(string) fullPath;

    /**
    The size of the file, already converted as a human readable string
    */
    immutable(string) sizeString;
}
