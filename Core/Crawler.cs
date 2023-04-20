


using System.Diagnostics;

public class Crawler
{

    private DriveInfo drive;
    private string searchString;
    private Action<string> resultsCallback;

    private HashSet<string> ignoreRoots;

    private Thread? thread;

    private CancellationTokenSource cancellationTokenSource = new CancellationTokenSource();

    public Crawler(DriveInfo drive, string searchString, Action<string> resultsCallback, HashSet<string> ignoreRoots)
    {
        this.drive = drive;
        this.searchString = searchString;
        this.resultsCallback = resultsCallback;
        this.ignoreRoots = ignoreRoots;
    }

    public void Start()
    {
        // Start a new thread
        // In the thread, call the SearchDirectory method
        // Pass the drive root directory as the parameter
        // Pass the searchString as the parameter
        // Pass the resultsCallback as the parameter

        this.thread = new Thread(() => SearchDirectory(drive.RootDirectory, searchString, resultsCallback, cancellationTokenSource.Token));
        thread.Start();
    }

    public void Wait()
    {
        // Wait for the thread to finish
        Debug.Assert(this.thread != null);
        thread?.Join();
    }

    private void SearchDirectory(DirectoryInfo root, string searchString, Action<string> resultsCallback, CancellationToken cancellationToken)
    {

        // Use breadth-first
        // Use a queue
        // Add the root directory to the queue
        // While the queue is not empty
        //      Get the next directory from the queue
        //      Search the directory for files
        //      Search the directory for subdirectories
        //      Add the subdirectories to the queue
        //      Repeat
        List<DirectoryInfo> directories = new List<DirectoryInfo>();
        directories.Add(root);

        while (directories.Count > 0 && !cancellationToken.IsCancellationRequested)
        {
            DirectoryInfo currentDirectory = directories.First();
            directories.RemoveAt(0);
            if (ignoreRoots.Contains(currentDirectory.FullName))
            {
                continue;
            }
            Trace.WriteLine("Searching " + currentDirectory.FullName);

            FileInfo[] files;
            try
            {
                files = currentDirectory.GetFiles();
            }
            catch (Exception e)
            {
                Trace.WriteLine("Error: " + e.Message);
                continue;
            }

            foreach (var file in files)
            {
                if (TokenSearch(file.Name, searchString))
                {
                    resultsCallback(file.FullName);
                }
            }

            DirectoryInfo[] subDirectories;
            try
            {
                subDirectories = currentDirectory.GetDirectories();
                // Good cheap heuristic to make the search faster
                subDirectories = subDirectories.OrderByDescending(d => d.LastWriteTime).ToArray();


            }
            catch (Exception e)
            {
                Trace.WriteLine("Error: " + e.Message);
                continue;
            }
            foreach (var subDirectory in subDirectories)
            {
                if (TokenSearch(subDirectory.Name, searchString))
                {
                    resultsCallback(subDirectory.FullName);
                    // Good cheap heuristic to make the search faster
                    directories.Insert(0, subDirectory);
                }
                else
                {
                    directories.Add(subDirectory);
                }
            }
        }
    }

    /// <summary>
    /// Returns a string representation of the crawler
    /// </summary>
    /// <returns></returns>
    public override string ToString()
    {
        return drive.Name;
    }

    /// <summary>
    /// Stop the crawler
    /// </summary>
    public void Stop()
    {
        // Stop the thread
        resultsCallback = (string result) => { };
        cancellationTokenSource.Cancel();

    }

    public static bool TokenSearch(string searchInto, string searchFor)
    {

        searchInto = searchInto.ToLower();
        searchFor = searchFor.ToLower();
        var tokens = searchFor.Split(' ');
        for (int i = 0; i < tokens.Length; i++)
        {
            if (!searchInto.Contains(tokens[i]))
            {
                return false;
            }
        }
        return true;
    }
}