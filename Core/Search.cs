



using System;
using System.Collections.Concurrent;
using System.IO;


namespace Drill.Core
{
    public class Search
    {


        private readonly ConcurrentQueue<FileSystemInfo> ParallelResults = new();
        private static readonly object UserName = Environment.UserName;

        private readonly CancellationTokenSource cancellationTokenSource = new();

        private SearchQueue directoriesToExplore;

        private readonly string searchString;


#if DEBUG
        private readonly List<DirectoryInfo> debugExploredDirs = [];
        private bool dumpExecuted;

#endif

        public Search(in string searchString)
        {
            directoriesToExplore = new(searchString);
            this.searchString = searchString;
        }

        public delegate void FatalErrorCallback(Exception e);



        private Task? scan;

        public void StartAsync(in FatalErrorCallback errorHandler)
        {
            if (scan != null)
            {
                throw new Exception("Drill already scanning");
            }

            if (searchString == string.Empty)
            {
                return;
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
#if DEBUG
                    Debug.Print(e.Message);
#endif
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

                    FileSystemInfo[] fsi = DiskRead.SafeGetFileSystemInfosInDirectory(rootFolderInfo);
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

                    List<DirectoryInfo> directoriesResults = GenerateDrillResults(directoriesList.ToArray(), searchString, cancellationTokenSource.Token);
                    for (int i = 0; i < directoriesResults.Count; i++)
                    {
                        DirectoryInfo item = directoriesResults[i];
                        if (cancellationTokenSource.IsCancellationRequested)
                            return;

                        ParallelResults.Enqueue(item);
                    }

                    List<FileInfo> filesResults = GenerateDrillResults(filesList.ToArray(), searchString, cancellationTokenSource.Token);
                    for (int i = 0; i < filesResults.Count; i++)
                    {
                        FileInfo item = filesResults[i];
                        if (cancellationTokenSource.IsCancellationRequested)
                            return;

                        ParallelResults.Enqueue(item);
                    }


                    for (int i = 0; i < directoriesList.Count; i++)
                    {
                        DirectoryInfo item = directoriesList[i];
                        if (cancellationTokenSource.IsCancellationRequested)
                            return;

                        // We don't follow symlinks
                        if ((item.Attributes & FileAttributes.ReparsePoint) != FileAttributes.ReparsePoint)
                            directoriesToExplore.Add(item);
                    }
                }
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
