using Drill.Core;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using static Drill.Core.Search;

namespace Core
{
    internal class Crawler
    {
        private bool _stopRequested;
        private readonly DirectoryInfo root;
        private readonly List<string> blacklisted;
        private readonly string searchString;

        // THIS IS HEAVY CALL WIN32 CACHE IT
        private readonly static string UserName = Environment.UserName;
        private readonly FatalErrorCallback errorHandler;
        private Task task;
        private static readonly ConcurrentQueue<DrillResult> ParallelResults = new();



        public Crawler(DirectoryInfo root, string searchString, List<string> blacklisted, Search.FatalErrorCallback errorHandler)
        {
            this.root = root;
            this.blacklisted = blacklisted;
            this.searchString = searchString;
            this.errorHandler = errorHandler;

        }

        internal void StartAsync()
        {
            task = Task.Run(() =>
            {
                // string userFolderPath = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);


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
            });
        }

        internal void StopAsync()
        {
            _stopRequested = true;
        }

        internal void Wait()
        {
            task.Wait();
            ParallelResults.Clear();
        }

        public  List<DrillResult> PopResults(int count)
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
