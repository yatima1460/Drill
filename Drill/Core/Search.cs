


using System.Collections.Concurrent;
using System.Diagnostics;

namespace Drill.Core
{
    public class Search
    {

        private static bool _stopRequested;

        private static readonly ConcurrentQueue<DrillResult> ParallelResults = new();
        private static readonly object UserName = Environment.UserName;
        static readonly HashSet<string> dict = new HashSet<string>();


        static Search()
        {
            using var stream =  FileSystem.OpenAppPackageFileAsync("words_alpha.txt").Result;
            using var reader = new StreamReader(stream);

            var contents = reader.ReadToEnd();
            
            foreach (var item in contents.Split("\r\n"))
            {
                if (item.Length > 4)
                dict.Add(item);
            }

            // done
        }

        private enum SearchPriority
        {
            Low,
            Normal,
            High
        }


        public delegate void FatalErrorCallback(Exception e);

        

        private static Task? scan;

        public static void StartAsync(string searchString, FatalErrorCallback errorHandler)
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



                SearchQueue directoriesToExplore = new();


                directoriesToExplore.AddHighPriority(new DirectoryInfo(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile)));
                directoriesToExplore.AddHighPriority(new DirectoryInfo(Environment.GetFolderPath(Environment.SpecialFolder.Recent)));
                directoriesToExplore.AddHighPriority(new DirectoryInfo(Environment.GetFolderPath(Environment.SpecialFolder.MyMusic)));
                directoriesToExplore.AddNormalPriority(new DirectoryInfo(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles)));
                directoriesToExplore.AddNormalPriority(new DirectoryInfo(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86)));
                directoriesToExplore.AddHighPriority(new DirectoryInfo(Environment.GetFolderPath(Environment.SpecialFolder.Desktop)));
                directoriesToExplore.AddHighPriority(new DirectoryInfo(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments)));
                directoriesToExplore.AddHighPriority(new DirectoryInfo(Environment.GetFolderPath(Environment.SpecialFolder.MyVideos)));
                directoriesToExplore.AddHighPriority(new DirectoryInfo($"C:\\Users\\{UserName}\\Downloads"));
                directoriesToExplore.AddLowPriority(new DirectoryInfo($"C:\\Users\\{UserName}\\AppData"));

                directoriesToExplore.AddHighPriority(new DirectoryInfo($"/Users/{UserName}/Library/Mobile Documents/com~apple~CloudDocs/"));


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
                        switch (d.DriveType)
                        {
                            case DriveType.Unknown:
                                directoriesToExplore.AddLowPriority(d.RootDirectory);
                                break;
                            case DriveType.NoRootDirectory:
                                break;
                            case DriveType.Removable:
                                directoriesToExplore.AddHighPriority(d.RootDirectory);
                                break;
                            case DriveType.Fixed:
                                if (d.RootDirectory.FullName == "C:\\")
                                {
                                    directoriesToExplore.AddLowPriority(d.RootDirectory);
                                }
                                else
                                {
                                    directoriesToExplore.AddNormalPriority(d.RootDirectory);
                                }
                                break;
                            case DriveType.Network:
                                directoriesToExplore.AddNormalPriority(d.RootDirectory);
                                break;
                            case DriveType.CDRom:
                                directoriesToExplore.AddLowPriority(d.RootDirectory);
                                break;
                            case DriveType.Ram:
                                directoriesToExplore.AddNormalPriority(d.RootDirectory);
                                break;
                            default:
                                directoriesToExplore.AddLowPriority(d.RootDirectory);
                                break;
                        }
                    }
                }


                _stopRequested = false;
                scan = new Task(() =>
                {

                    try
                    {


                        while (_stopRequested == false && directoriesToExplore.Count != 0)
                        {
                            DirectoryInfo rootFolderInfo = directoriesToExplore.PopHighestPriority();

                            

                            try
                            {
                                // Directory.GetFileSystemEntries()
                                FileInfo[] subs = rootFolderInfo.GetFiles("*", SearchOption.TopDirectoryOnly);

                                foreach (FileInfo file in subs)
                                {
                                    if (_stopRequested) break;
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
                                        ParallelResults.Enqueue(drillResult);
                                    }
                                }

                                DirectoryInfo[] di = rootFolderInfo.GetDirectories("*", SearchOption.TopDirectoryOnly);
                                foreach (DirectoryInfo sub in di)
                                {
                                    if (_stopRequested) break;
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
                                        ParallelResults.Enqueue(drillResult);
                                    }


                                        switch (GetDirectoryPriority(sub, searchString))
                                    {
                                        case SearchPriority.Low:
                                            directoriesToExplore.AddLowPriority(sub);
                                            break;
                                        case SearchPriority.Normal:
                                            directoriesToExplore.AddNormalPriority(sub);
                                            break;
                                        case SearchPriority.High:
                                            directoriesToExplore.AddHighPriority(sub);
                                            break;
                                    }

                                    






                                    //List<DirectoryInfo> directoryInfosPrioritized = new List<DirectoryInfo>();

                                    //foreach (DirectoryInfo item in directoriesToExplore)
                                    //{
                                    //    if (sub.Name.StartsWith(".") ||
                                    //        (sub.Attributes & FileAttributes.Hidden) == FileAttributes.Hidden ||
                                    //        (sub.Attributes & FileAttributes.System) == FileAttributes.System ||
                                    //         (sub.Attributes & FileAttributes.Temporary) == FileAttributes.Temporary ||
                                    //         sub.FullName.StartsWith("C:\\Windows")
                                    //        )
                                    //    {
                                    //        directoriesToExplore.Add(sub);
                                    //    }
                                    //    else
                                    //    {
                                    //        directoriesToExplore.Insert(0, sub);
                                    //    }

                                    //}
                                    //directoriesToExplore = directoryInfosPrioritized;


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
                        //errorHandler(e);
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

        private static SearchPriority GetDirectoryPriority(DirectoryInfo sub, string searchString)
        {
            if (
            sub.Name.StartsWith(".") 
            || (sub.Attributes & FileAttributes.Hidden) == FileAttributes.Hidden ||
            (sub.Attributes & FileAttributes.System) == FileAttributes.System ||
            (sub.Attributes & FileAttributes.Temporary) == FileAttributes.Temporary ||
            sub.FullName.StartsWith("C:\\Windows")
            || sub.FullName.StartsWith($"C:\\Users\\{UserName}\\AppData")
            || (sub.Parent != null &&  sub.Parent.FullName == "C:\\")
            || (sub.Attributes & FileAttributes.ReparsePoint) == FileAttributes.ReparsePoint
            )
            {
                return SearchPriority.Low;
            }


            if (StringUtils.TokenMatching(searchString, sub.Name))
            {
                // it contains in the name the search string
                return SearchPriority.High;
            }

            if (dict.Contains(sub.Name.ToLower()))
            {
                // it contains in the name the search string
                return SearchPriority.High;
            }

            if (
                sub.Parent != null && sub.Parent.FullName == ($"C:\\Users\\{UserName}")
                || (sub.LastAccessTime - DateTime.Now).TotalDays < 30
               || (sub.LastWriteTime - DateTime.Now).TotalDays < 30
                )
            {
                // it contains in the name the search string
                return SearchPriority.High;
            }





            return SearchPriority.Normal;

        }

        public static void Stop()
        {
            _stopRequested = true;
            if (scan != null)
            {  
                scan.Wait();
                scan.Dispose();
                scan = null;
            }
            ParallelResults.Clear();   
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
