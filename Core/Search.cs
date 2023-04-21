


using System.Diagnostics;


public class Search
{

    private string searchString;
    Action<string> resultsCallback;

    List<Crawler> crawlers = new List<Crawler>();


    public Search(string searchString, Action<string> resultsCallback)
    {

        if (searchString == null)
        {
            throw new ArgumentException("Search string cannot be null");
        }
        if (searchString.Length == 0)
        {
            throw new ArgumentException("Search string cannot be empty");
        }
        if (resultsCallback == null)
        {
            throw new ArgumentException("Results callback cannot be null");
        }
        this.searchString = searchString;
        this.resultsCallback = resultsCallback;
    }

    public void Start()
    {

        if (crawlers.Count > 0)
        {
            throw new InvalidOperationException("Search already started");
        }
        // Get a list of all mounted drives
        // For each drive, create a new Crawler
        // Start each crawler
        Debug.WriteLine("Starting search...");


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
            crawler.Start();
        }



    }

    public void Wait()
    {

        if (crawlers.Count == 0)
        {
            throw new InvalidOperationException("Search not started");
        }
        foreach (var crawler in crawlers)
        {
            Debug.WriteLine("Waiting for crawler " + crawler + " to finish...");
            crawler.Wait();
        }
        Debug.WriteLine("Search finished.");
    }



    /// Stop the search
    public void Stop()
    {
        if (crawlers.Count == 0)
        {
            throw new InvalidOperationException("Search not started");
        }
        // Stop each crawler
        foreach (var crawler in crawlers)
        {
            crawler.Stop();
        }
        crawlers.Clear();
    }

}