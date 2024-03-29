


namespace Drill.Core;
public abstract class Module {

    protected readonly string SearchString;
    protected readonly Action<Uri> ResultsCallback;
    protected readonly CancellationToken CancellationToken;

    /// <summary>
    /// Initialize the module
    /// Here you should load any data or resources
    /// </summary>
    public Module(string searchString, Action<Uri> resultsCallback, CancellationToken token){
        this.SearchString = searchString;
        this.ResultsCallback = resultsCallback;
        this.CancellationToken = token;
    }

    /// <summary>
    /// Start the module
    /// Here you should start any threads or processes
    /// </summary>
    public abstract void Start();


    /// <summary>
    /// Wait for the module to finish
    /// Here you should wait for any threads or processes to finish
    /// </summary>
    public abstract void Wait();

    /// <summary>
    /// Is the module still running?
    /// </summary>
    public abstract bool IsRunning();
    
}