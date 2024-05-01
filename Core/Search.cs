

using System.Collections.Concurrent;
using System.Diagnostics;

namespace Drill.Core
{
    public class Search
    {

        public delegate void FatalErrorCallback(Exception e);
        private static bool _stopRequested = false;
        private static readonly ConcurrentQueue<DrillResult> ParallelResults = new();
        private static readonly ConcurrentBag<string> Visited = [];
        private static readonly List<Task> ParallelThreads = [];

        public static void StartAsync(string searchString, FatalErrorCallback errorHandler)
        {
            try
            {
                if (_stopRequested)
                {
                    throw new Exception("Stop requested, can't start right now");
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
                    Environment.SpecialFolder.MyVideos
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
                        Debug.Print(e.Message);
                        continue;
                    }
                }

                
                try
                {
                    roots.Add(new DirectoryInfo($"/Users/{Environment.UserName}/Library/Mobile Documents/com~apple~CloudDocs/"));
                }
                catch (Exception e)
                {
                    Debug.Print(e.Message);
                }

                DriveInfo[] allDrives = [];
                try {
                    allDrives = DriveInfo.GetDrives();
                }
                catch (Exception e)
                {
                    Debug.Print(e.Message);
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

                    ParallelThreads.Add(Task.Run(() =>
                    {
                        // string userFolderPath = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
                        

                        try
                        {
                            List<DirectoryInfo> directoriesToExplore = [root];

                            while (_stopRequested == false && directoriesToExplore.Count != 0)
                            {
                                DirectoryInfo rootFolderInfo = directoriesToExplore[0];
                                directoriesToExplore.RemoveAt(0);


                                // To prevent any kind of loops
                                if (Visited.Contains(rootFolderInfo.FullName))
                                {
                                    continue;
                                }
                                Visited.Add(rootFolderInfo.FullName);


                                try
                                {
                                    // Directory.GetFileSystemEntries()
                                    FileSystemInfo[] subs = rootFolderInfo.GetFileSystemInfos("*", SearchOption.TopDirectoryOnly);
                                    
                                    foreach (FileSystemInfo sub in subs)
                                    {
                                        // TODO move to Platforms
                                        if (
                                            sub.FullName == $"/Users/{Environment.UserName}/Pictures/Photos Library.photoslibrary" || 
                                            sub.FullName == $"/Users/{Environment.UserName}/Library/Calendars" ||
                                            sub.FullName == $"/Users/{Environment.UserName}/Library/Reminders"  ||
                                            sub.FullName == $"/Users/{Environment.UserName}/Library/Contacts"
                                            )
                                        {
                                            continue;
                                        }
                                   
                                        bool isDirectory = (sub.Attributes & FileAttributes.Directory) == FileAttributes.Directory;
                                        bool isResult = StringUtils.TokenMatching(searchString, sub.Name);
                                        
                                        if (isResult)
                                        {
                                            // Better to create the DrillResult on the backend than the UI thread to not stall it
                                            DrillResult drillResult = new()
                                            {
                                                Name = sub.Name,
                                                FullPath = sub.FullName,
                                                Path = rootFolderInfo.FullName,
                                                Date = sub.LastWriteTime.ToString("F"),
                                                Size = isDirectory ? "" : StringUtils.GetHumanReadableSize((FileInfo)sub),
                                                // TODO: different icon for .app on Mac
                                                Icon = isDirectory ? "📁" : ExtensionIcon.GetIcon(sub.Extension.ToLower())
                                            };
                                            ParallelResults.Enqueue(drillResult);
                                            
                                            // If the result is also folder it means
                                            // it contains in the name the search string
                                            if (isDirectory)
                                            {
                                                // Go vertical because it could be important
                                                directoriesToExplore.Insert(0, (DirectoryInfo)sub);
                                            }
                                        }
                                        else
                                        {
                                            // If the current file is a directory we queue it for crawling
                                            if (isDirectory)
                                            {
                                                //if (sub.Name.StartsWith(".") ||
                                                //    (sub.Attributes & FileAttributes.Hidden) == FileAttributes.Hidden ||
                                                //    (sub.Attributes & FileAttributes.System) == FileAttributes.System ||
                                                //     (sub.Attributes & FileAttributes.Temporary) == FileAttributes.Temporary ||
                                                //     sub.FullName.StartsWith("C:\\Windows")
                                                //    )

                                                // Go horizontal
                                                directoriesToExplore.Add((DirectoryInfo)sub);
                                            }
                                        }

                                        
                                    }
                                }
                                catch (Exception e)
                                {
                                    Debug.Print(e.Message);
                                    continue;
                                }
                            }

                        }
                        catch (Exception e)
                        {
                            _stopRequested = true;
                            Debug.Print(e.Message);
                            errorHandler(e);
                        }
                    }));
                }
            }
            catch (Exception e)
            {
                _stopRequested = true;
                Debug.Print(e.Message);
                errorHandler(e);
            }

        }

        public static void Stop()
        {
            if (_stopRequested)
            {
                throw new Exception("Stop already requested");
            }
            _stopRequested = true;
            foreach (Task item in ParallelThreads)
            {
                item.Wait();
            }
            ParallelThreads.Clear();
            ParallelResults.Clear();
            Visited.Clear();
            _stopRequested = false;
        }

        public static List<DrillResult> PopResults(int count)
        {
            if (_stopRequested)
            {
                return [];
            }
            int minSize = Math.Min(count, ParallelResults.Count);
            List<DrillResult> results = new(minSize);
            for (int i = 0; i < minSize; i++)
            {
                if (ParallelResults.TryDequeue(out DrillResult? result))
                {
                    results.Add(result);
                }
            }
            return results;
        }
    }
}
