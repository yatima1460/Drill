namespace CLI;

using System.Diagnostics;


public class CLI
{
    public static void Main(string[] args)
    {
        Debug.WriteLine("Drill debug output");
        if (args.Length == 0)
        {
            Console.WriteLine("No arguments provided.");
            return;
        }

        Debug.WriteLine("Starting search...");
        Search search = new Search(args[0], ResultsCallback);
        search.Start();
        search.Wait();
    }

    public static void ResultsCallback(string result)
    {
        Console.WriteLine(result);
    }

}
