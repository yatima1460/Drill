


using Microsoft.UI.Xaml.Controls;
using System.Collections.Concurrent;
using System.Diagnostics;
using System.Threading;

namespace Drill.Core
{
    public class Search
    {


        private readonly ConcurrentQueue<DrillResult> ParallelResults = new();
        private static readonly object UserName = Environment.UserName;

        private readonly CancellationTokenSource cancellationTokenSource = new();

        private SearchQueue directoriesToExplore;

        private readonly string searchString;


#if DEBUG
        private readonly List<DirectoryInfo> debugExploredDirs = [];
        private bool dumpExecuted;

#endif

        public Search(string searchString)
        {
            directoriesToExplore = new(searchString);
            this.searchString = searchString;
        }

        public delegate void FatalErrorCallback(Exception e);



        private Task? scan;

        public void StartAsync(FatalErrorCallback errorHandler)
        {

            try
            {
                // THIS IS HEAVY CALL WIN32 CACHE IT
                string UserName = Environment.UserName;

                if (scan != null)
                {
                    throw new Exception("Crawlers already scanning");
                }

                // If the search string is empty do nothing
                if (searchString == string.Empty)
                {
                    return;
                }






                directoriesToExplore.Add(new DirectoryInfo(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile)));
                directoriesToExplore.Add(new DirectoryInfo(Environment.GetFolderPath(Environment.SpecialFolder.Recent)));
                directoriesToExplore.Add(new DirectoryInfo(Environment.GetFolderPath(Environment.SpecialFolder.MyMusic)));
                directoriesToExplore.Add(new DirectoryInfo(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles)));
                directoriesToExplore.Add(new DirectoryInfo(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86)));
                directoriesToExplore.Add(new DirectoryInfo(Environment.GetFolderPath(Environment.SpecialFolder.Desktop)));
                directoriesToExplore.Add(new DirectoryInfo(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments)));
                directoriesToExplore.Add(new DirectoryInfo(Environment.GetFolderPath(Environment.SpecialFolder.MyVideos)));
                directoriesToExplore.Add(new DirectoryInfo($"C:\\Users\\{UserName}\\Downloads"));
                directoriesToExplore.Add(new DirectoryInfo($"C:\\Users\\{UserName}\\AppData"));

                directoriesToExplore.Add(new DirectoryInfo($"/Users/{UserName}/Library/Mobile Documents/com~apple~CloudDocs/"));


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
                        foreach (var item in fsi)
                        {
                            if ((item.Attributes & FileAttributes.Directory) == FileAttributes.Directory)
                            {
                                directoriesList.Add((DirectoryInfo)item);
                            }
                            else
                            {
                                filesList.Add((FileInfo)item);
                            }
                        }

                        foreach (var item in GenerateDrillResults(rootFolderInfo, directoriesList.ToArray(), searchString, cancellationTokenSource.Token))
                        {
                            ParallelResults.Enqueue(item);
                        }

                        foreach (var item in GenerateDrillResults(rootFolderInfo, filesList.ToArray(), searchString, cancellationTokenSource.Token))
                        {
                            ParallelResults.Enqueue(item);
                        }


                        foreach (DirectoryInfo item in directoriesList)
                        {
                            // We don't follow symlinks
                            if ((item.Attributes & FileAttributes.ReparsePoint) != FileAttributes.ReparsePoint)
                                directoriesToExplore.Add(item);
                        }
                    }
                });
                scan.Start();

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

        /// <summary>
        /// Given a list of directories filters them to generate drill results
        /// </summary>
        /// <param name="rootFolderInfo"></param>
        /// <param name="directories"></param>
        /// <param name="searchString"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        private static List<DrillResult> GenerateDrillResults(DirectoryInfo rootFolderInfo, DirectoryInfo[] directories, string searchString, CancellationToken cancellationToken)
        {



            List<DrillResult> results = new();
            foreach (DirectoryInfo sub in directories)
            {
                if (cancellationToken.IsCancellationRequested) break;
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
                    results.Add(drillResult);
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
        private static List<DrillResult> GenerateDrillResults(DirectoryInfo rootFolderInfo, FileInfo[] subs, string searchString, CancellationToken cancellationToken)
        {
            // Directory.GetFileSystemEntries()

            List<DrillResult> results = new();

            foreach (FileInfo file in subs)
            {
                if (cancellationToken.IsCancellationRequested) break;
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
                        Icon = ExtensionIcon.GetIcon(file.Extension.ToLower())
                    };

                    // this may stall for a sec
                    results.Add(drillResult);
                }
            }

            return results;
        }



        public void Stop()
        {
            cancellationTokenSource.Token.ThrowIfCancellationRequested();
            cancellationTokenSource.Cancel();
            if (scan != null)
            {
                scan.Wait();
                scan.Dispose();
                scan = null;
            }
            ParallelResults.Clear();
        }

        public List<DrillResult> PopResults(int count)
        {
            if (cancellationTokenSource.Token.IsCancellationRequested)
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

        public override string? ToString()
        {
            return $"{searchString} - {directoriesToExplore}";
        }
    }
}
