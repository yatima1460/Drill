


namespace Drill;

public static class IO {

    public static void OpenFile(string path)
    {
        try
        {
              Process.Start(new ProcessStartInfo
                {
                    FileName = "explorer.exe",
                    Arguments = "\"" + FullPath + "\""
                });
        }
        catch (Exception e)
        {
            DisplayAlert("Error opening file", "FullPath: " + FullPath + "\n" + e.ToString(), "OK");
        }
    }


    public static void OpenPath(string path)
    {
        try
        {
            Process.Start(new ProcessStartInfo
                {
                    FileName = "explorer.exe",
                    Arguments = string.Format("/select,\"{0}\"", FullPath)
                });
        }
        catch (Exception e)
        {
            DisplayAlert("Error opening file", "FullPath: " + FullPath + "\n" + e.ToString(), "OK");
        }
    }
   

}