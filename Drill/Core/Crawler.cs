

using Drill.Core;
using System.Collections.Concurrent;




namespace Drill.Core
{
    internal class Crawler
    {
        private bool _stopRequested;
        private readonly DirectoryInfo root;
        private readonly List<string> blacklisted;
        private readonly string searchString;

        // THIS IS HEAVY CALL WIN32 CACHE IT
        private readonly static string UserName = Environment.UserName;
        //private readonly FatalErrorCallback errorHandler;
        private Thread thread;
        private static readonly ConcurrentQueue<DrillResult> ParallelResults = new();



        public Crawler(DirectoryInfo root, string searchString, List<string> blacklisted, Search.FatalErrorCallback errorHandler)
        {
            this.root = root;
            this.blacklisted = blacklisted;
            this.searchString = searchString;
            //this.errorHandler = errorHandler;
            this.thread = new Thread(this.StartSync);

        }

        internal void StartAsync()
        {
            thread.Start(); 
        }

        internal void StartSync()
        {

            try
            {
                SearchQueue directoriesToExplore = new();
                directoriesToExplore.AddHighPriority(root);

                while (_stopRequested == false && directoriesToExplore.Count != 0)
                {
                    DirectoryInfo rootFolderInfo = directoriesToExplore.PopHighPriority();
            
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


                            if (IO.IsSystem(sub))
                            {

                                directoriesToExplore.AddLowPriority(sub);
                            }
                            else
                            {
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

                                    // the result is also folder it means
                                    // it contains in the name the search string
                                    // Go vertical because it could be important
                                    directoriesToExplore.AddHighPriority(sub);
                                }
                                else
                                {
                                    directoriesToExplore.AddNormalPriority(sub);
                                }
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


        }

        internal void StopAsync()
        {
            _stopRequested = true;
        }

        internal void Wait()
        {
            thread.Join();
            ParallelResults.Clear();
        }

        public List<DrillResult> PopResults(int count)
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
