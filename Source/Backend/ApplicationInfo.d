module ApplicationInfo;


/**
Struct containing the data Drill found about installed applications
*/
struct ApplicationInfo
{

    /*
    Name of the installed application
    */
    immutable(string) name;

    /*
    Location where the app is installed
    */
    // string installedLocation;
    
    version(linux)
    {
        /*
        Path to the .desktop file (Linux only)
        */
        immutable(string) desktopFileFullPath;
        
        /*
        Command line to execute it on the .desktop file
        */
        immutable(string) exec;

        /*
        Cleaned command line execution line
        removed % and splitted by space
        */
        immutable(string[]) execProcess;

        /*
        Icon to use
        */
        immutable(string) icon = "application-x-executable";

        /*
        Date modified of the .desktop file
        */
        immutable(string) desktopFileDateModifiedString;
    }
    // version(Windows)
    // {

    // }
}