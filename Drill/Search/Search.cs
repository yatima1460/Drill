using Drill.Backend;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using static System.Runtime.InteropServices.JavaScript.JSType;
using System.Xml.Linq;
using static Drill.MainPage;
using static System.Environment;


namespace Drill.Search
{
    class Search
    {

        public delegate void FatalErrorCallback(Exception e);
        private static bool StopRequested = false;
        private static readonly ConcurrentQueue<DrillResult> ParallelResults = new();
        private static readonly ConcurrentBag<string> visited = [];
        private static readonly List<Task> ParallelThreads = [];

        public static void StartAsync(string searchString, FatalErrorCallback errorHandler)
        {
            try
            {
                if (StopRequested)
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
                    catch (Exception)
                    {
                        continue;
                    }
                }

                DriveInfo[] allDrives = DriveInfo.GetDrives();
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

                            while (StopRequested == false && directoriesToExplore.Count != 0)
                            {
                                DirectoryInfo rootFolderInfo = directoriesToExplore[0];
                                directoriesToExplore.RemoveAt(0);


                                // To prevent any kind of loops
                                if (visited.Contains(rootFolderInfo.FullName))
                                {
                                    continue;
                                }
                                visited.Add(rootFolderInfo.FullName);


                                try
                                {
                                    FileSystemInfo[] subs = rootFolderInfo.GetFileSystemInfos("*", SearchOption.TopDirectoryOnly);
                                    
                                    foreach (FileSystemInfo sub in subs)
                                    {

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
                                                Icon = isDirectory ? "📁" : ExtensionIcon.GetIcon(sub.Extension.ToLower())
                                            };
                                            ParallelResults.Enqueue(drillResult);


                                            // If the result is also folder it means
                                            // it contains in the name the search string
                                            // Go vertical because it could be important
                                            if (isDirectory)
                                            {
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

                                // We can't go deeper unless we are root, skip it
                                catch (UnauthorizedAccessException)
                                {
                                    continue;
                                }
                            }

                        }
                        catch (Exception e)
                        {
                            StopRequested = true;
                            errorHandler(e);
                        }
                    }));
                }
            }
            catch (Exception e)
            {
                StopRequested = true;
                errorHandler(e);
            }

        }

        public static void Stop()
        {
            if (StopRequested)
            {
                throw new Exception("Stop already requested");
            }
            StopRequested = true;
            foreach (Task item in ParallelThreads)
            {
                item.Wait();
            }
            ParallelThreads.Clear();
            ParallelResults.Clear();
            visited.Clear();
            StopRequested = false;
        }

        public static List<DrillResult> PopResults(int count)
        {
            if (StopRequested)
            {
                return new List<DrillResult>();
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
