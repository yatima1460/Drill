using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Drill.Core
{
    class Search
    {
        public delegate void ErrorHandler(Exception e);

        private static bool stop = false;
        //private static SearchResultHandler callback = Blackhole;
        //private static ErrorHandler errorCallback;
        private static Task? currentSearchTask;
        private static string LastSearchString = string.Empty;
   

        /// <summary>
        /// Collection holding all the results from the backend
        /// </summary>
        private static ConcurrentQueue<DrillResult> ParallelResults = [];

        public static void StartAsync(string searchString, ErrorHandler errorHandler)
        {
            // If new string is the same as old one do nothing
            if (LastSearchString == searchString)
            {
                return;
            }

            // If the search string is empty do nothing
            if (searchString == string.Empty)
            {
                return;
            }

            stop = false;

            currentSearchTask = Task.Run(() =>
            {
                // string userFolderPath = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);

                try
                {
                    HashSet<string> visited = [];
                    Queue<DirectoryInfo> directoriesToExplore = [];

                    directoriesToExplore.Enqueue(new DirectoryInfo(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile)));

                    DriveInfo[] allDrives = DriveInfo.GetDrives();
                    foreach (DriveInfo d in allDrives)
                    {
                        if (d.IsReady == true && (d.DriveType == DriveType.Removable || d.DriveType == DriveType.Fixed || d.DriveType == DriveType.Network))
                        {
                            directoriesToExplore.Enqueue(d.RootDirectory);
                        }
                    }


                    while (stop == false && directoriesToExplore.Count != 0)
                    {
                        DirectoryInfo rootFolderInfo = directoriesToExplore.Dequeue();

                        // To prevent loops
                        if (visited.Contains(rootFolderInfo.FullName))
                        {
                            continue;
                        }
                        visited.Add(rootFolderInfo.FullName);


                        try
                        {
                            FileSystemInfo[] subs = rootFolderInfo.GetFileSystemInfos("*", SearchOption.TopDirectoryOnly);

                            Queue<DirectoryInfo> lowPriority = new();

                            foreach (FileSystemInfo sub in subs)
                            {
                                if (StringUtils.TokenMatching(searchString, sub.Name))
                                {
                                    // Better to create the DrillResult on the backend than the UI thread to not stall it
                                    ParallelResults.Enqueue(new DrillResult(sub));
                                    //callback(new DrillResult(sub));
                                }
                                // If the current file is a directory we queue it for crawling
                                if ((sub.Attributes & FileAttributes.Directory) == FileAttributes.Directory)
                                {
                                    if (sub.Name.StartsWith(".") ||
                                        (sub.Attributes & FileAttributes.Hidden) == FileAttributes.Hidden ||
                                        (sub.Attributes & FileAttributes.System) == FileAttributes.System ||
                                         (sub.Attributes & FileAttributes.Temporary) == FileAttributes.Temporary ||
                                         sub.FullName.StartsWith("C:\\Windows")
                                        )
                                    {
                                        lowPriority.Enqueue((DirectoryInfo)sub);
                                    }
                                    else
                                    {
                                        directoriesToExplore.Enqueue((DirectoryInfo)sub);
                                    }
                                }
                            }

                            // Queue at the end the low priority ones
                            foreach (FileSystemInfo sub in lowPriority)
                            {
                                directoriesToExplore.Enqueue((DirectoryInfo)sub);
                            }
                        }
                        // We can't go deeper unless we are root, skip it
                        catch (UnauthorizedAccessException)
                        {
                            continue;
                        }
                    }

                    currentSearchTask = null;
                    stop = true;
                }
                catch (Exception e)
                {
                    errorHandler(e);
                }
            });
        }

        public static void Stop()
        {
            stop = true;
            currentSearchTask?.Wait();
            ParallelResults.Clear();
        }

        public static DrillResult? PopResult()
        {
            if (ParallelResults.TryDequeue(out DrillResult? result))
            {
                return result;
            }
            return null;
        }
    }
}
