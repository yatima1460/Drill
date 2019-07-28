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

    import std.algorithm : cmp;

    /*
    Checks if the exec process command line is the same
    */
    // bool opEquals(ref const ApplicationInfo b) const
    // {
    //     if (this is b) return true;
    //     return cmp(this.exec,b.exec) == 0;
    // }

    /*
    Returns the name of the application
    */
    string toString() const
    {
        return name;
    }

    /*
    Starts the application in a new process
    */
    // void opCall() const
    // {
    //     import std.process : spawnProcess;
    //     import std.process : Config;
    //     spawnProcess(execProcess, null, Config.none, null);
    // }

    extern (D) size_t toHash() const nothrow @safe
    {
        return this.exec.hashOf();
    }



    int opCmp(ref const ApplicationInfo s) const
    {
        import std.algorithm : cmp;

        return cmp(this.desktopFileDateModifiedString,s.desktopFileDateModifiedString);
    }
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
