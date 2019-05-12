module drill.core.fileinfo;

/**
FileInfo is a struct filled by the information a crawler can find about a file
*/
struct FileInfo
{
    /***
    true if the file is a directory
    */
    bool isDirectory;

    /***
    true if the file is a normal file
    */
    bool isFile;

    /***
    true if is a symbolic link
    */
    bool isSymbolic;

    /***
    string of the date modified
    */
    string dateModifiedString;

    /*** 
    the parent folder
    */
    string containingFolder;

    /***
    name of the icon to use on the left of the name
    */
    string iconName;

    /***
    the filename with extension
    */
    string fileName;

    /***
    only the extension with the dot (ex: .png) 
    */
    string extension;



    string fullPath;



    string sizeString;





}

//     this(DirEntry de)
//     {

//     }

//     void isDirectory()
//     {

//     }

//     string getDateModifiedString()
//     {

//     }

//     void openContainingFolder()
//     {

//     }

//     void openFile()
//     {

//     }

//     string getContainingFolder()
//     {

//     }

//     string getFileName()
//     {

//     }

//     string getIconName()
//     {

//     }

// }
