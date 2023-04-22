





using System.Diagnostics;

namespace Drill.Core.Modules.LocalFileSearch;

class LocalFileSearch : Module
{

    
    private List<Crawler> crawlers = new List<Crawler>();

    public LocalFileSearch(string searchString, Action<string> resultsCallback, CancellationToken token) : base(searchString, resultsCallback, token)
    {
         var roots = new HashSet<string>();

        var drives = DriveInfo.GetDrives();
        foreach (var drive in drives)
        {
            Debug.WriteLine("Starting crawler for drive " + drive);
            if (!drive.IsReady)
            {
                Debug.WriteLine("Drive " + drive + " is not ready.");
                continue;
            }

            roots.Add(drive.RootDirectory.FullName);
        }

        var goodRoots = new List<string> {
            // Basic folders
            "/Applications",
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "Applications"),
            Environment.GetFolderPath(Environment.SpecialFolder.Desktop),
            Environment.GetFolderPath(Environment.SpecialFolder.MyMusic),
            Environment.GetFolderPath(Environment.SpecialFolder.MyPictures),
            Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments),
            Environment.GetFolderPath(Environment.SpecialFolder.MyVideos),
            Environment.GetFolderPath(Environment.SpecialFolder.MyComputer),
            Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
            // iCloud
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "Library", "Mobile Documents"),
            // Steam
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "Steam", "steamapps", "common"),
            // Origin
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "Origin Games"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "Ubisoft"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "GOG Galaxy"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "Epic Games"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "Battle.net"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "Microsoft Games"),
        };


        foreach (var path in goodRoots)
        {
            if (Directory.Exists(path))
            {
                roots.Add(path);
            }
        }

        var blacklist = new HashSet<string>();
        // Add Library
        // blacklist.Add(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "Library"));
        // // Avoid main Mac HD
        // blacklist.Add("/Volumes/Macintosh HD");
        // blacklist.Add("/System/Volumes/Data/Volumes/Macintosh HD");
        // blacklist.Add("/System");
        

        foreach (var root in roots)
        {
            var ignoreRoots = new HashSet<string>(blacklist);
            ignoreRoots.UnionWith(roots);
            ignoreRoots.Remove(root);
            Crawler crawler = new Crawler(root, searchString, resultsCallback, ignoreRoots);
            crawlers.Add(crawler);
            
        }
    }

    public override bool IsRunning()
    {
        return crawlers.Any(c => c.IsRunning());
    }

    public override void Start()
    {
        foreach (var crawler in crawlers)
        {
            crawler.Start();
        }
    }


    public override void Wait()
    {
        foreach (var crawler in crawlers)
        {
            crawler.Wait();
        }
    }
}