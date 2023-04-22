





using System.Diagnostics;

namespace Drill.Core.Modules.LocalFileSearch;

class LocalFileNameSearch : Module
{

    private HashSet<string> roots = new HashSet<string>();

    private Thread? thread;

    public LocalFileNameSearch(string searchString, Action<Uri> resultsCallback, CancellationToken cancellationToken) : base(searchString, resultsCallback, cancellationToken)
    {
        var drives = DriveInfo.GetDrives();
        foreach (var drive in drives)
        {
            Debug.WriteLine("Starting crawler for drive " + drive);
            if (!drive.IsReady)
            {
                Debug.WriteLine("Drive " + drive + " is not ready.");
                continue;
            }
            if (drive.DriveType == DriveType.Network)
            {
                Debug.WriteLine("Drive " + drive + " is not local.");
                continue;
            }

            roots.Add(drive.RootDirectory.FullName);
        }

        var goodRoots = new List<string> {
            // Basic folders
            "/",
            "/Volumes/Macintosh HD",
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

        this.thread = new Thread(() => SearchDirectory());
    }

    public override bool IsRunning()
    {
        return thread != null && thread.IsAlive;
    }

    public override void Start()
    {
        Debug.Assert(this.thread != null);
        thread.Start();
    }


    public override void Wait()
    {
        Debug.Assert(this.thread != null);
        thread?.Join();
    }

    private void SearchDirectory()
    {
        HashSet<string> visited = new HashSet<string>();
        LinkedList<DirectoryInfo> queue = new LinkedList<DirectoryInfo>();

        try
        {
            foreach (var root in roots)
            {
                queue.AddLast(new DirectoryInfo(root));
            }
        }
        catch (Exception e)
        {
            Trace.WriteLine("Error: " + e.Message);
            return;
        }


        while (queue.Count > 0 && !CancellationToken.IsCancellationRequested)
        {
            DirectoryInfo currentDirectory = queue.First();
            queue.RemoveFirst();

          
          
            Trace.WriteLine("Searching " + currentDirectory.FullName);

         

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

                if (visited.Contains(subDirectory.FullName))
                {
                    continue;
                }
                visited.Add(subDirectory.FullName);

                // Avoid strange directories
                if (!subDirectory.Attributes.HasFlag(FileAttributes.Directory)
                || subDirectory.Attributes.HasFlag(FileAttributes.ReparsePoint)
                || subDirectory.Attributes.HasFlag(FileAttributes.Offline))
                {
                   continue;
                }

                bool isResult = SearchString.Contains(Path.DirectorySeparatorChar) ? subDirectory.FullName.ToLower().Contains(SearchString.ToLower()) : TokenSearch(subDirectory.Name, SearchString);   

                if (isResult)
                {
                    // If the directory has the search token in the name, add it to the front of the queue
                    queue.AddFirst(subDirectory);
                     // Start in a new ThreadPool to avoid blocking the main thread
                    ThreadPool.QueueUserWorkItem(
                        (state) => ResultsCallback(new Uri(subDirectory.FullName))
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
                if (TokenSearch(file.Name, SearchString))
                {
                    // Create file Uri
                    // Call resultsCallback with the Uri
                    
              
                     ThreadPool.QueueUserWorkItem(
                        (state) => ResultsCallback(new Uri(file.FullName))
                    );
                }
            }
        }
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