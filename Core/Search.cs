

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

                // THIS IS HEAVY CALL WIN32 CACHE IT
                var UserName = Environment.UserName;

                foreach (DirectoryInfo root in roots)
                {

                    ParallelThreads.Add(Task.Run(() =>
                    {
                        // string userFolderPath = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);

                        // Other roots that we are exploring so we can skip them if we encounter them
                        List<string> blacklisted = [];
                        foreach (var item in roots)
                        {
                            blacklisted.Add(item.FullName);
                        }
                        blacklisted.Remove(root.FullName);

                        try
                        {
                            List<DirectoryInfo> directoriesToExplore = [root];

                            while (_stopRequested == false && directoriesToExplore.Count != 0)
                            {
                                DirectoryInfo rootFolderInfo = directoriesToExplore[0];
                                directoriesToExplore.RemoveAt(0);

                                // Because of tree structure we hit a root we are already exploring
                                if (blacklisted.Contains(rootFolderInfo.FullName))
                                {
                                    continue;
                                }

                                try
                                {
                                    // Directory.GetFileSystemEntries()
                                    FileInfo[] subs = rootFolderInfo.GetFiles("*", SearchOption.TopDirectoryOnly);

                                    foreach (FileInfo file in subs)
                                    {
                                        if (StringUtils.TokenMatching(searchString, file.Name))
                                        {
                                            // Better to create the DrillResult on the backend than the UI thread to not stall it
                                            DrillResult drillResult = new()
                                            {
                                                Name = file.Name,
                                                FullPath = file.FullName,
                                                Path = rootFolderInfo.FullName,
                                                Date = file.LastWriteTime.ToString("F"),
                                                Size = StringUtils.GetHumanReadableSize(file),
                                                // TODO: different icon for .app on Mac
                                                Icon = ExtensionIcon.GetIcon(file.Extension.ToLower())
                                            };

                                            // this may stall for a sec
                                            ParallelResults.Enqueue(drillResult);
                                        }
                                    }

                                    DirectoryInfo[] di = rootFolderInfo.GetDirectories("*", SearchOption.TopDirectoryOnly);
                                    foreach (DirectoryInfo sub in di)
                                    {
                                        // TODO move to Platforms
                                        if (
                                            sub.FullName == $"/Users/{UserName}/Pictures/Photos Library.photoslibrary" ||
                                            sub.FullName == $"/Users/{UserName}/Library/Calendars" ||
                                            sub.FullName == $"/Users/{UserName}/Library/Reminders" ||
                                            sub.FullName == $"/Users/{UserName}/Library/Contacts"
                                            )
                                        {
                                            continue;
                                        }


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
                                                Size = "",
                                                // TODO: different icon for .app on Mac
                                                Icon = "📁"
                                            };

                                            // this may stall for a sec
                                            ParallelResults.Enqueue(drillResult);

                                            // the result is also folder it means
                                            // it contains in the name the search string
                                            // Go vertical because it could be important
                                            directoriesToExplore.Insert(0, sub);
                                        }
                                        else
                                        {

                                            //if (sub.Name.StartsWith(".") ||
                                            //    (sub.Attributes & FileAttributes.Hidden) == FileAttributes.Hidden ||
                                            //    (sub.Attributes & FileAttributes.System) == FileAttributes.System ||
                                            //     (sub.Attributes & FileAttributes.Temporary) == FileAttributes.Temporary ||
                                            //     sub.FullName.StartsWith("C:\\Windows")
                                            //    )

                                            // Go horizontal
                                            directoriesToExplore.Add(sub);

                                        }


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

                        }
                        catch (Exception e)
                        {
                            _stopRequested = true;
#if DEBUG
                            Debug.Print(e.Message);
#endif
                            errorHandler(e);
                        }
                    }));
                }
            }
            catch (Exception e)
            {
                _stopRequested = true;
#if DEBUG
                Debug.Print(e.Message);
#endif
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
                if (ParallelResults.TryDequeue(out DrillResult result))
                {
                    results.Add(result);
                }
            }
            return results;
        }
    }
}
