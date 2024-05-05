


using System.Collections.Concurrent;
using System.Diagnostics;

namespace Drill.Core
{
    public class Search
    {

        public delegate void FatalErrorCallback(Exception e);
   
        private static List<Crawler> crawlers = [];

        public static void StartAsync(string searchString, FatalErrorCallback errorHandler)
        {
            try
            {
                if (crawlers.Count != 0)
                {
                    throw new Exception("Crawlers already scanning");
                }

                // If the search string is empty do nothing
                if (searchString == string.Empty)
                {
                    return;
                }

                Environment.SpecialFolder[] specialFolders = [
                    Environment.SpecialFolder.UserProfile,
                    Environment.SpecialFolder.Recent,
                    Environment.SpecialFolder.Desktop,
                    Environment.SpecialFolder.MyDocuments,
                    Environment.SpecialFolder.MyVideos,
                    Environment.SpecialFolder.MyMusic,
                    Environment.SpecialFolder.ProgramFilesX86,
                    Environment.SpecialFolder.ProgramFiles,
                ];

                List<DirectoryInfo> roots = [];
                foreach (Environment.SpecialFolder specialFolder in specialFolders)
                {
                    try
                    {
                        string path = Environment.GetFolderPath(specialFolder);
                        if (Directory.Exists(path))
                        {
                            roots.Add(new DirectoryInfo(path));
                        }
                    }
                    catch (Exception e)
                    {
#if DEBUG
                        Debug.Print(e.Message);
#endif
                        continue;
                    }
                }


                try
                {
                    roots.Add(new DirectoryInfo($"/Users/{Environment.UserName}/Library/Mobile Documents/com~apple~CloudDocs/"));
                }
                catch (Exception e)
                {
#if DEBUG
                    Debug.Print(e.Message);
#endif
                }

                DriveInfo[] allDrives = [];
                try
                {
                    allDrives = DriveInfo.GetDrives();
                }
                catch (Exception e)
                {
#if DEBUG
                    Debug.Print(e.Message);
#endif
                }
                foreach (DriveInfo d in allDrives)
                {
                    if (d.IsReady == true && (d.DriveType == DriveType.Removable || d.DriveType == DriveType.Fixed || d.DriveType == DriveType.Network))
                    {
                        if (d.RootDirectory.Exists)
                        {
                            roots.Add(d.RootDirectory);
                        }
                    }
                }

                foreach (DirectoryInfo root in roots)
                {
                    // Other roots that we are exploring so we can skip them if we encounter them
                    List<string> blacklisted = [];
                    foreach (var item in roots)
                    {
                        blacklisted.Add(item.FullName);
                    }
                    blacklisted.Remove(root.FullName);

                    Crawler c = new(root, searchString, blacklisted, errorHandler);
                    crawlers.Add(c);
                    c.StartAsync();
                }
            }
            catch (Exception e)
            {
                Stop();
#if DEBUG
                Debug.Print(e.Message);
#endif
                errorHandler(e);
            }
        }

        public static void Stop()
        {
            foreach (Crawler c in crawlers)
            {
                c.StopAsync();
            }
            foreach (Crawler c in crawlers)
            {
                c.Wait();
            }
            crawlers.Clear();
        }

        public static List<DrillResult> PopResults(int count)
        {
            List<DrillResult> allResults = [];
            foreach (Crawler item in crawlers)
            {
                allResults.AddRange(item.PopResults(count));
            }
           
            return allResults;
        }
    }
}
