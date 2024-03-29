﻿namespace CLI;

using System.Diagnostics;
using Drill.Core;

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

        
        Search search = new Search(args[0], ResultsCallback);
        search.Start();
        search.Wait();

        Console.CancelKeyPress += delegate {
            search.Stop();
        };
    }

    public static void ResultsCallback(Uri result)
    {
        Console.WriteLine(result);
    }

}
