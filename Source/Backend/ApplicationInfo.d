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


/**
Returns a list of installed applications with their data saved in the ApplicationInfo struct
*/
@system ApplicationInfo[] getApplications()
{
    version(linux)
    {
        ApplicationInfo[] applications;
        import Utils : getDesktopFiles;
        string[] desktopFiles = getDesktopFiles();
        foreach (desktopFile; desktopFiles)
        {
            import Utils : readDesktopFile;
            applications ~= readDesktopFile(desktopFile);
        }
        return applications;
    }
    else
    {
        return [];
    }
}