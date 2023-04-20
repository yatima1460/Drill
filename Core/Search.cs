


using System.Diagnostics;

public class Search {

    private string searchString;
    Action<string> resultsCallback;
    
    List<Crawler> crawlers = new List<Crawler>();


    public Search(string searchString, Action<string> resultsCallback) {
        this.searchString = searchString;
        this.resultsCallback = resultsCallback;
    }

    public void Start() {
        // Get a list of all mounted drives
        // For each drive, create a new Crawler
        // Start each crawler
        Debug.WriteLine("Starting search...");
        foreach (var drive in DriveInfo.GetDrives()) {
            Crawler crawler = new Crawler(drive, searchString, resultsCallback);
            crawlers.Add(crawler);
            crawler.Start();
        }
    }

    public void Wait() {
        foreach (var crawler in crawlers) {
            Debug.WriteLine("Waiting for crawler "+crawler+" to finish...");
            crawler.Wait();
        }
        Debug.WriteLine("Search finished.");
    }


    
    /// Stop the search
    public void Stop() {
        // Stop each crawler
        foreach (var crawler in crawlers) {
            crawler.Stop();
        }
    }

}