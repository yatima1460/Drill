/**
Struct containing the data Drill found about installed applications
*/
struct ApplicationInfo
{

    /*
    Name of the installed application
    */
    immutable(string) name;
    invariant
    {
        assert(name !is null);
        assert(name.length > 0);
    }

    /*
    Location where the app is installed
    */
    // string installedLocation;

    version (linux)
    {
        /*
        Path to the .desktop file (Linux only)
        */
        immutable(string) desktopFileFullPath;
        invariant
        {
            assert(desktopFileFullPath !is null);
            assert(desktopFileFullPath.length > 0);
        }

        /*
        Command line to execute it on the .desktop file (Linux only)
        */
        immutable(string) exec;
        invariant
        {
            assert(exec !is null);
            assert(exec.length > 0);
        }

        /*
        Cleaned command line execution line (Linux only)
        removed % and splitted by space
        */
        immutable(string[]) execProcess;
        invariant
        {
            assert(execProcess !is null);
            assert(execProcess.length > 0);
        }

        /*
        Icon to use
        */
        immutable(string) icon = "application-x-executable";
        invariant
        {
            assert(icon !is null);
            assert(icon.length > 0);
        }

        /*
        Date modified of the .desktop file  (Linux only)
        */
        immutable(string) desktopFileDateModifiedString;
        invariant
        {
            assert(desktopFileDateModifiedString !is null);
            assert(desktopFileDateModifiedString.length > 0);
        }
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
    version (linux)
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
