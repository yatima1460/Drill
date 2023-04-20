


using System.Diagnostics;

public class Crawler {

    private DriveInfo drive;
    private string searchString;
    private Action<string> resultsCallback;

    private Thread? thread;

    public Crawler(DriveInfo drive, string searchString, Action<string> resultsCallback) {
        this.drive = drive;
        this.searchString = searchString;
        this.resultsCallback = resultsCallback;
    }

    public void Start() {
        // Start a new thread
        // In the thread, call the SearchDirectory method
        // Pass the drive root directory as the parameter
        this.thread = new Thread(() => SearchDirectory(drive.RootDirectory, searchString, resultsCallback));
        thread.Start();
    }

    public void Wait() {
        // Wait for the thread to finish
        Debug.Assert(this.thread != null);
        thread?.Join();
    }

    private void SearchDirectory(DirectoryInfo directory, string searchString, Action<string> resultsCallback) {
    
        // Use breadth-first
        // Use a queue
        // Add the root directory to the queue
        // While the queue is not empty
        //      Get the next directory from the queue
        //      Search the directory for files
        //      Search the directory for subdirectories
        //      Add the subdirectories to the queue
        //      Repeat
        Queue<DirectoryInfo> directories = new Queue<DirectoryInfo>();
        directories.Enqueue(directory);
        
        while (directories.Count > 0) {
            DirectoryInfo currentDirectory = directories.Dequeue();
            Trace.WriteLine("Searching "+currentDirectory.FullName);
            
            FileInfo[] files;
            try {
                 files = currentDirectory.GetFiles();
            } catch (Exception e) {
                continue;
            }
           
            foreach (var file in files) {
                if (file.Name.ToLower().Contains(searchString.ToLower())) {
                    resultsCallback(file.FullName);
                }
            }

            DirectoryInfo[] subDirectories;
            try {
                subDirectories = currentDirectory.GetDirectories();
            } catch (Exception e) {
                continue;
            }
            foreach (var subDirectory in subDirectories) {
                if (subDirectory.Name.ToLower().Contains(searchString.ToLower())) {
                    resultsCallback(subDirectory.FullName);
                }
                directories.Enqueue(subDirectory);
            }
        }
    }

    /// <summary>
    /// Returns a string representation of the crawler
    /// </summary>
    /// <returns></returns>
    public override string ToString() {
        return drive.Name;
    }

    /// <summary>
    /// Stop the crawler
    /// </summary>
    public void Stop() {
        // Stop the thread
        thread?.Abort();
    }
}