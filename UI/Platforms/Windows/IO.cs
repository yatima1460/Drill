


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
   

}