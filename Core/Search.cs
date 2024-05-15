



using System;
using System.Collections.Concurrent;
using System.Diagnostics;
using System.IO;


namespace Drill.Core
{
    public class Search(string searchString)
    {
        /// <summary>
        /// Data structure containing the actual results found
        /// </summary>
        private readonly ConcurrentQueue<FileSystemInfo> ParallelResults = new();

        /// <summary>
        /// OS username, cached because this call can be quite expensive (at least on Windows)
        /// </summary>
        private static readonly object UserName = Environment.UserName;

        /// <summary>
        /// Basically a pointer to a fancy boolean to decide when to stop the scan
        /// </summary>
        private readonly CancellationTokenSource cancellationTokenSource = new();

        /// <summary>
        /// Smart queue of stuff to scan, sorted using heuristics
        /// </summary>
        private readonly SearchQueue directoriesToExplore = new(searchString);

        /// <summary>
        /// The parallel task scanning
        /// </summary>
        private Task? scan;


        /// <summary>
        /// Starts a scan
        /// </summary>
        /// <exception cref="DrillException">Error if already scanning or empty search string</exception>
        public void StartAsync()
        {
            if (scan != null)
            {
                throw new DrillException("Drill already scanning");
            }

            if (searchString == string.Empty)
            {
                throw new DrillException("Can't scan using an empty string");
            }


            directoriesToExplore.Add(@"C:\Program Files (x86)\Steam\steamapps\common");
            directoriesToExplore.Add($"C:\\Users\\{UserName}\\AppData\\Roaming\\Microsoft\\Windows\\Start Menu\\Programs\\Steam");
            directoriesToExplore.Add($"C:\\Users\\{UserName}\\AppData\\Roaming\\Microsoft\\Windows\\Start Menu");
            directoriesToExplore.Add(@"C:\ProgramData\Microsoft\Windows\Start Menu");
            directoriesToExplore.Add(Environment.SpecialFolder.UserProfile);
            directoriesToExplore.Add(Environment.SpecialFolder.Recent);
            directoriesToExplore.Add(Environment.SpecialFolder.MyMusic);
            directoriesToExplore.Add(Environment.SpecialFolder.ProgramFiles);
            directoriesToExplore.Add(Environment.SpecialFolder.ProgramFilesX86);
            directoriesToExplore.Add(Environment.SpecialFolder.Desktop);
            directoriesToExplore.Add(Environment.SpecialFolder.MyDocuments);
            directoriesToExplore.Add(Environment.SpecialFolder.MyVideos);
            directoriesToExplore.Add($"C:\\Users\\{UserName}\\Downloads");
            directoriesToExplore.Add($"/Users/{UserName}/Library/Mobile Documents/com~apple~CloudDocs/");


            DriveInfo[] allDrives = [];
            try
            {
                allDrives = DriveInfo.GetDrives();
            }
            catch (Exception e)
            {
                Debug.Print(e.Message);
            }

            foreach (DriveInfo d in allDrives)
            {
                if (cancellationTokenSource.IsCancellationRequested)
                    return;
                if (d.IsReady == true && d.RootDirectory.Exists)
                {
                    directoriesToExplore.Add(d.RootDirectory);
                }
            }

            scan = new Task(() =>
            {
                while (!cancellationTokenSource.IsCancellationRequested && directoriesToExplore.PopHighestPriority(out DirectoryInfo? rootFolderInfo))
                {
                    // We have explored everything possible, it's time to stop
                    if (rootFolderInfo == null)
                    {
                        break;
                    }
                    //#if DEBUG
                    //                        if (debugExploredDirs.Count < 1000)
                    //                        {
                    //                            debugExploredDirs.Add(rootFolderInfo);
                    //                        }
                    //                        else if (!dumpExecuted)
                    //                        {

                    //                            List<string> lines = [];
                    //                            foreach (var item in debugExploredDirs)
                    //                            {
                    //                                lines.Add(SearchQueue.GetDirectoryPriority(item, searchString) + "," + item.FullName);
                    //                            }


                    //                            File.WriteAllLines(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Desktop), $"Drill-explored-{searchString}.txt"), lines);

                    //                            dumpExecuted = true;
                    //                        }

                    //#endif

                    // Reading the disk once and then figuring out which FileSystemInfo
                    // is a file and which is a folder using Attributes seems faster
                    // than actually reading 2 times with GetDirectories and GetFiles
                    FileSystemInfo[] fsi;
                    try
                    {
                        fsi = rootFolderInfo.GetFileSystemInfos("*", SearchOption.TopDirectoryOnly);
                    }
                    catch (Exception e)
                    {
                        Debug.WriteLine(e);
                        continue;
                    }
                    List<FileInfo> filesList = new(fsi.Length);
                    List<DirectoryInfo> directoriesList = new(fsi.Length);
                    for (int i = 0; i < fsi.Length; i++)
                    {
                        FileSystemInfo item = fsi[i];
                        if (cancellationTokenSource.IsCancellationRequested)
                            return;

                        if ((item.Attributes & FileAttributes.Directory) == FileAttributes.Directory)
                        {
                            directoriesList.Add((DirectoryInfo)item);
                        }
                        else
                        {
                            filesList.Add((FileInfo)item);
                        }
                    }

                    // Iterate over all stuff found and check if it's a result
                    for (int i = 0; i < fsi.Length; i++)
                    {
                        if (cancellationTokenSource.IsCancellationRequested)
                            return;

                        FileSystemInfo item = fsi[i];

                        if (StringUtils.TokenMatching(searchString, item.Name))
                        {
                            // this may stall for a sec
                            ParallelResults.Enqueue(item);       
                        }
                    }
                    
                    // Now we iterate over the directories that were found
                    // and if they are not fully banned we queue them
                    for (int i = 0; i < directoriesList.Count; i++)
                    {
                        if (cancellationTokenSource.IsCancellationRequested)
                            return;

                        DirectoryInfo item = directoriesList[i];
                        // TODO move to Platforms
                        if (
                            item.FullName == $"/Users/{UserName}/Pictures/Photos Library.photoslibrary" ||
                            item.FullName == $"/Users/{UserName}/Library/Calendars" ||
                            item.FullName == $"/Users/{UserName}/Library/Reminders" ||
                            item.FullName == $"/Users/{UserName}/Library/Contacts"
                            )
                        {
                            continue;
                        }    

                        // We don't follow symlinks
                        if ((item.Attributes & FileAttributes.ReparsePoint) != FileAttributes.ReparsePoint)
                            directoriesToExplore.Add(item);
                    }
                }

                Debug.WriteLine("Search done.");
            });
            scan.Start();

        }

        readonly Dictionary<string, int> subDirectoriesCountCache = new();

        /// <summary>
        /// Given a list of directories filters them to generate drill results
        /// </summary>
        /// <param name="rootFolderInfo"></param>
        /// <param name="directories"></param>
        /// <param name="searchString"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        private static List<DirectoryInfo> GenerateDrillResults(in DirectoryInfo[] directories, in string searchString, in CancellationToken cancellationToken)
        {



            List<DirectoryInfo> results = [];
            foreach (DirectoryInfo sub in directories)
            {
                if (cancellationToken.IsCancellationRequested) 
                    return [];
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

                if (StringUtils.TokenMatching(searchString, sub.Name))
                {
                   

                    // this may stall for a sec
                    results.Add(new DirectoryInfo(sub.FullName));
                }




            }

            return results;
        }


        /// <summary>
        /// Given a folder generates Drill results of all the files inside
        /// </summary>
        /// <param name="rootFolderInfo"></param>
        /// <param name="searchString"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        private static List<FileInfo> GenerateDrillResults(in FileInfo[] subs, in string searchString, in CancellationToken cancellationToken)
        {
            // Directory.GetFileSystemEntries()

            List<FileInfo> results = new();

            foreach (FileInfo file in subs)
            {
                if (cancellationToken.IsCancellationRequested) 
                    return [];
                if (StringUtils.TokenMatching(searchString, file.Name))
                {

                    // this may stall for a sec
                    results.Add(new FileInfo(file.FullName));
                }
            }

            return results;
        }



        public AggregateException? Stop()
        {
            cancellationTokenSource.Cancel();
            if (scan != null)
            {
                scan.Wait();
                var e = scan.Exception;
                scan.Dispose();
                scan = null;
                return e;
            }
            ParallelResults.Clear();
            return null;
        }

        public List<FileSystemInfo> PopResults(in int count)
        {
            int minSize = Math.Min(count, ParallelResults.Count);
            List<FileSystemInfo> results = new(minSize);
            for (int i = 0; i < minSize; i++)
            {
                if (cancellationTokenSource.Token.IsCancellationRequested)
                {
                    return [];
                }
                if (ParallelResults.TryDequeue(out FileSystemInfo result))
                {
                    results.Add(result);
                }
            }
            return results;
        }

        public override string? ToString()
        {
            return searchString;
        }
    }
}
