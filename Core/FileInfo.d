

/**
FileInfo is a struct filled by the information a crawler found about files matching the search
*/
@safe struct FileInfo
{
    string thread;
    // /**
    // The original mountpoint used by a crawler that found this file
    // */
    // string originalMountpoint;

    /**
    true if the file is a directory
    */
    bool isDirectory;

    /**
    true if the file is a normal file
    */
    bool isFile;

    /**
    true if is a symbolic link
    */
    //bool isSymbolic;

    /**
    string of the date modified
    */
    string dateModifiedString;

    /***
    the parent folder path
    */
    string containingFolder;

    /**
    name of the icon to use on the left of the name
    */
    //string iconName;

    /**
    the filename with extension
    */
    string fileName;

    /**
    the filename with extension but lower string
    */
    string fileNameLower;

    /**
    only the extension with the dot (ex: .png)
    */
    string extension;

    /**
    Complete full path of the file
    */
    string fullPath;

    /**
    The size of the file, already converted as a human readable string
    */
    string sizeString;


    // debug
    // {
    //     nothrow ~this()
    //     {
    //         import core.stdc.stdio;
    //         printf("FileInfo destroyed\n");
    //     }
    // }
}
