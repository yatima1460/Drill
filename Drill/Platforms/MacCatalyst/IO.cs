


using System.Diagnostics;

namespace Drill;


public static class IO {

    public static void OpenFile(string fullPath)
    {
        Process.Start("open","\"" + fullPath + "\"");
    }


    public static void OpenPath(string fullPath)
    {
        Process.Start("open","-R \"" + fullPath + "\"");
    }
   
    // TODO:
    //public static string[] GetInterestingRoots()
    //{

    //}
}