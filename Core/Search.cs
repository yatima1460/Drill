


using System.Diagnostics;

namespace Drill.Core;

public class Search
{

    private string searchString;
    Action<Uri> resultsCallback;

    private CancellationTokenSource cancellationTokenSource = new CancellationTokenSource();

    private List<Module> modules = new List<Module>();


    public Search(string searchString, Action<Uri> resultsCallback)
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

        modules.Add(new Modules.LocalFileSearch.LocalFileSearch(searchString, resultsCallback, cancellationTokenSource.Token));
        this.searchString = searchString;
        this.resultsCallback = resultsCallback;
    }

    public void Start()
    {
        if (modules.Count == 0)
        {
            throw new InvalidOperationException("No modules to start");
        }
        if (modules.Any(m => m.IsRunning()))
        {
            throw new InvalidOperationException("Search already started");
        }

        Debug.WriteLine("Starting search...");
        foreach (var module in modules)
        {
            Debug.WriteLine("Starting module " + module);
            module.Start();
            Debug.WriteLine("Module " + module + " started");
        }
    }


    /// Returns true if at least one module is running
    public bool IsRunning()
    {
        foreach (var module in modules)
        {
            if (module.IsRunning())
            {
                return true;
            }
        }
        return false;
    }

    public void Wait()
    {
        if (!IsRunning())
        {
            
            throw new InvalidOperationException("Search not started");
        }
        foreach (var module in modules)
        {
            Debug.WriteLine("Waiting for module " + module);
            module.Wait();
        }
        Debug.WriteLine("Search finished.");
    }

    /// Stop the search
    public void Stop()
    {
        if (!IsRunning())
        {
            throw new InvalidOperationException("Search not started");
        }
        cancellationTokenSource.Cancel();
    }

}