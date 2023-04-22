using System.Diagnostics;
using Drill.Core;

namespace Tests;



public class UnitTest1
{
    [Fact]
    public void SimpleStartAndStop()
    {
        Search s = new Search("test", (Uri result) => {
            Trace.WriteLine("SimpleStartAndStop: "+result);
        });
        s.Start();
        s.Stop();
    }

    [Fact]
    public void PassInvalidSearchString()
    {
        Assert.Throws<ArgumentException>(() => new Search(null, (Uri result) => {
            Trace.WriteLine("PassInvalidSearchString: "+result);
        }));
    }

    
    [Fact]
    public void PassInvalidResultsCallback()
    {
        Assert.Throws<ArgumentException>(() => new Search("test", null));
    }

        
    [Fact]
    public void PassEmptySearchString()
    {
        Assert.Throws<ArgumentException>(() => new Search("", (Uri result) => {
            Trace.WriteLine("PassEmptySearchString: "+result);
        }));
    }

    [Fact(Timeout = 1000)]
    public void StartTwice()
    {
        Search s = new Search("test", (Uri result) => {
            Trace.WriteLine("StartTwice: "+result);
        });
        s.Start();
        Assert.Throws<InvalidOperationException>(() => s.Start());
    }
    

    [Fact]
    public void StopTwice()
    {
        Search s = new Search("test", (Uri result) => {
            Trace.WriteLine("StopTwice: "+result);
        });
        s.Start();
        s.Stop();
        Assert.Throws<InvalidOperationException>(() => s.Stop());
    }

    [Fact]
    public void StopWithoutStarting()
    {
        Search s = new Search("test", (Uri result) => {
            Trace.WriteLine("StopWithoutStarting: "+result);
        });
        Assert.Throws<InvalidOperationException>(() => s.Stop());
    }

    [Fact]
    public void WaitWithoutStarting()
    {
        Search s = new Search("test", (Uri result) => {
            Trace.WriteLine("WaitWithoutStarting: "+result);
        });
        Assert.Throws<InvalidOperationException>(() => s.Wait());
    }

    // [Fact(Timeout = 1000)]
    // public void WaitWithoutStopping()
    // {
    //     Search s = new Search("test", (string result) => {
    //         Console.WriteLine("WaitWithoutStopping: "+result);
    //     });
    //     s.Start();
    //     Assert.Throws<InvalidOperationException>(() => s.Wait());
    // }

    [Fact]
    public void PassAllNull()
    {
        Assert.Throws<ArgumentException>(() => new Search(null, null));
    }


//     [Fact]
//     FIXME: This test is broken
//     public void StartAndStopMultipleTimesWithWait()
//     {
//         Search s = new Search("test", (Uri result) => {
//             Trace.WriteLine("StartAndStopMultipleTimesWithWait: "+result);
//         });
//         s.Start();
//         s.Stop();
//         s.Wait();
//         s.Start();
//         s.Stop();
//         s.Wait();
//         s.Start();
//         s.Stop();
//     }
}