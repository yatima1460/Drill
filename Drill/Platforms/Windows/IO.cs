





using System.Diagnostics;

namespace Drill;

public static class IO {

    public static void OpenFile(string FullPath)
    {

        Process.Start(new ProcessStartInfo
        {
            FileName = "explorer.exe",
            Arguments = "\"" + FullPath + "\""
        });

    }


    public static void OpenPath(string FullPath)
    {

        Process.Start(new ProcessStartInfo
        {
            FileName = "explorer.exe",
            Arguments = string.Format("/select,\"{0}\"", FullPath)
        });

    }



    internal static string SpecialFolderSystem = Environment.GetFolderPath(Environment.SpecialFolder.System);
    internal static bool IsSystem(DirectoryInfo sub)
    {
        return sub.Name.StartsWith(".") ||
        (sub.Attributes & FileAttributes.Hidden) == FileAttributes.Hidden ||
        (sub.Attributes & FileAttributes.System) == FileAttributes.System ||
        (sub.Attributes & FileAttributes.Temporary) == FileAttributes.Temporary ||
        sub.FullName.StartsWith("C:\\Windows")
        || sub.FullName == "C:\\"
        || sub.FullName == SpecialFolderSystem
        ;
    }
}