


using System.Diagnostics;


namespace Drill.Core.Modules.LocalFileSearch;
public class Crawler
{
    public readonly string root;
    private string searchString;
    private Action<Uri> resultsCallback;

    private HashSet<string> ignoreRoots;

    private Thread? thread;

    private CancellationTokenSource cancellationTokenSource = new CancellationTokenSource();

    public Crawler(string root, string searchString, Action<Uri> resultsCallback, HashSet<string> ignoreRoots)
    {
        this.root = root;
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

        this.thread = new Thread(() => SearchDirectory(root, searchString, resultsCallback, cancellationTokenSource.Token));
        thread.Start();
    }

    public void Wait()
    {
        // Wait for the thread to finish
        Debug.Assert(this.thread != null);
        thread?.Join();
    }

    private void SearchDirectory(string root, string searchString, Action<Uri> resultsCallback, CancellationToken cancellationToken)
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
        LinkedList<DirectoryInfo> queue = new LinkedList<DirectoryInfo>();
        try
        {
            queue.AddLast(new DirectoryInfo(root));
        }
        catch (Exception e)
        {
            Trace.WriteLine("Error: " + e.Message);
            return;
        }


        while (queue.Count > 0 && !cancellationToken.IsCancellationRequested)
        {
            DirectoryInfo currentDirectory = queue.First();
            queue.RemoveFirst();

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
                    // Create file Uri
                    // Call resultsCallback with the Uri
                    
              
                     ThreadPool.QueueUserWorkItem(
                        (state) => resultsCallback(new Uri(file.FullName))
                    );
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
                // Avoid soft links
                if (subDirectory.Attributes != FileAttributes.Directory)
                {
                   continue;
                }

                bool isResult = searchString.Contains(Path.PathSeparator) ? subDirectory.FullName.ToLower().Contains(searchString.ToLower()) : TokenSearch(subDirectory.Name, searchString);   

               

                
                if (isResult)
                {
                    // If the directory has the search token in the name, add it to the front of the queue
                    queue.AddFirst(subDirectory);
                     // Start in a new ThreadPool to avoid blocking the main thread
                    ThreadPool.QueueUserWorkItem(
                        (state) => resultsCallback(new Uri(subDirectory.FullName))
                    );
                    continue;
                }

                    // If the directory is "bad", add it to the end of the queue
                    if (subDirectory.Attributes.HasFlag(FileAttributes.Hidden)
                        || subDirectory.Attributes.HasFlag(FileAttributes.System)
                        || subDirectory.Attributes.HasFlag(FileAttributes.Temporary)
                        || subDirectory.LastWriteTime < DateTime.Now.AddMonths(-3)
                        || subDirectory.LastAccessTime < DateTime.Now.AddMonths(-3)
                        || subDirectory.Extension == ".app"
                        || subDirectory.FullName.Contains(".app/")
                        || subDirectory.Name.StartsWith(".")
                        || subDirectory.Name.StartsWith("$")
                        || subDirectory.Name.StartsWith("~")
                        || Path.Join(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "Library").Equals(subDirectory.FullName)
                        || Path.Join(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "AppData").Equals(subDirectory.FullName)
                        || subDirectory.Name == "node_modules"
                        || subDirectory.FullName.StartsWith(@"C:\Windows")
                        || subDirectory.FullName.StartsWith("/System")
                        || subDirectory.FullName.StartsWith("/Library")
                        || subDirectory.FullName.StartsWith("/private")
                    )
                    {
                        queue.AddLast(subDirectory);
                    }
                    else
                    {
                        queue.AddFirst(subDirectory);
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
        return root;
    }

    /// <summary>
    /// Stop the crawler
    /// </summary>
    public void Stop()
    {
        // Stop the thread
        resultsCallback = (Uri result) => { };
        cancellationTokenSource.Cancel();

    }

    public bool IsRunning()
    {
        return thread != null && thread.IsAlive;
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