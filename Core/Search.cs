


using System.Diagnostics;


public class Search {

    private string searchString;
    Action<string> resultsCallback;
    
    List<Crawler> crawlers = new List<Crawler>();


    public Search(string searchString, Action<string> resultsCallback) {

        if (searchString == null) {
            throw new ArgumentException("Search string cannot be null");
        }
        if (searchString.Length == 0) {
            throw new ArgumentException("Search string cannot be empty");
        }
        if (resultsCallback == null) {
            throw new ArgumentException("Results callback cannot be null");
        }
        this.searchString = searchString;
        this.resultsCallback = resultsCallback;
    }

    public void Start() {

        if (crawlers.Count > 0) {
            throw new InvalidOperationException("Search already started");
        }
        // Get a list of all mounted drives
        // For each drive, create a new Crawler
        // Start each crawler
        Debug.WriteLine("Starting search...");
        var drives = DriveInfo.GetDrives();
        foreach (var drive in drives) {
            Debug.WriteLine("Starting crawler for drive "+drive);
            if (!drive.IsReady) {
                Debug.WriteLine("Drive "+drive+" is not ready.");
                continue;
            }
            HashSet<string> ignoreRoots = new HashSet<string>();
            // FIXME: this is (O(n^2) and should be O(n))?
            foreach (var otherDrive in drives) {
                if (otherDrive != drive) {
                    ignoreRoots.Add(otherDrive.RootDirectory.FullName);
                }
            }
            Crawler crawler = new Crawler(drive, searchString, resultsCallback, ignoreRoots);
            crawlers.Add(crawler);
            crawler.Start();
        }
    }

    public void Wait() {

        if (crawlers.Count == 0) {
            throw new InvalidOperationException("Search not started");
        }
        foreach (var crawler in crawlers) {
            Debug.WriteLine("Waiting for crawler "+crawler+" to finish...");
            crawler.Wait();
        }
        Debug.WriteLine("Search finished.");
    }


    
    /// Stop the search
    public void Stop() {
        if (crawlers.Count == 0) {
            throw new InvalidOperationException("Search not started");
        }
        // Stop each crawler
        foreach (var crawler in crawlers) {
            crawler.Stop();
        }
        crawlers.Clear();
    }

}