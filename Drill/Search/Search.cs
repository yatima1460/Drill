﻿using Drill.Backend;
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

namespace Drill.Backend
{
    class Search
    {
        private static List<FileSystemInfo> cache = [];
        public delegate void ErrorHandler(Exception e);

        private static bool stop = true;
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

            LastSearchString = searchString;

            // If the search string is empty do nothing
            if (searchString == string.Empty)
            {
                return;
            }

            stop = false;

            List<FileSystemInfo> newCache = [];
            foreach (var item in cache)
            {
                if (item.Exists)
                {
                    if (StringUtils.TokenMatching(searchString, item.Name))
                    {
                        bool isDirectory = (item.Attributes & FileAttributes.Directory) == FileAttributes.Directory;

                        // Better to create the DrillResult on the backend than the UI thread to not stall it
                        DrillResult drillResult = new()
                        {
                            Name = item.Name,
                            FullPath = item.FullName,
                            Path = item.FullName,
                            Date = item.LastWriteTime.ToString("F"),
                            Size = isDirectory ? "" : StringUtils.GetHumanReadableSize((FileInfo)item),
                            Icon = isDirectory ? "📁" : ExtensionIcon.GetIcon(item.Extension.ToLower())
                        };
                        ParallelResults.Enqueue(drillResult);
                        newCache.Add(item);
                    }
                }
            }
            cache = newCache;

            currentSearchTask = Task.Run(() =>
            {
                // string userFolderPath = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);

                try
                {
                    
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

                    HashSet<string> visited = new();

                    while (stop == false && directoriesToExplore.Count != 0)
                    {
                        DirectoryInfo rootFolderInfo = directoriesToExplore.Dequeue();

                        // To prevent any kind of loops
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
                                cache.Add(sub);
                                bool isDirectory = (sub.Attributes & FileAttributes.Directory) == FileAttributes.Directory;
                                
                                if (StringUtils.TokenMatching(searchString, sub.Name))
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
                                }

                                // If the current file is a directory we queue it for crawling
                                if (isDirectory)
                                {
                                    if (sub.Name.StartsWith(".") ||
                                        (sub.Attributes & FileAttributes.Hidden) == FileAttributes.Hidden ||
                                        (sub.Attributes & FileAttributes.System) == FileAttributes.System ||
                                         (sub.Attributes & FileAttributes.Temporary) == FileAttributes.Temporary ||
                                         sub.FullName.StartsWith("C:\\Windows")
                                        )
                                    {
                                        directoriesToExplore.Enqueue((DirectoryInfo)sub);
                                    }
                                    else
                                    {
                                        directoriesToExplore.Enqueue((DirectoryInfo)sub);
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

        public static List<DrillResult> PopResults(int count)
        {
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
