using Drill.Core;

namespace Tests;



public class UnitTest1
{
    [Fact]
    public void SimpleStartAndStop()
    {
        Search s = new Search("test", (Uri result) => {
            Console.WriteLine("SimpleStartAndStop: "+result);
        });
        s.Start();
        s.Stop();
    }

    [Fact]
    public void PassInvalidSearchString()
    {
        Assert.Throws<ArgumentException>(() => new Search(null, (Uri result) => {
            Console.WriteLine("PassInvalidSearchString: "+result);
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
            Console.WriteLine("PassEmptySearchString: "+result);
        }));
    }

    [Fact(Timeout = 1000)]
    public void StartTwice()
    {
        Search s = new Search("test", (Uri result) => {
            Console.WriteLine("StartTwice: "+result);
        });
        s.Start();
        Assert.Throws<InvalidOperationException>(() => s.Start());
    }
    

    [Fact]
    public void StopTwice()
    {
        Search s = new Search("test", (Uri result) => {
            Console.WriteLine("StopTwice: "+result);
        });
        s.Start();
        s.Stop();
        Assert.Throws<InvalidOperationException>(() => s.Stop());
    }

    [Fact]
    public void StopWithoutStarting()
    {
        Search s = new Search("test", (Uri result) => {
            Console.WriteLine("StopWithoutStarting: "+result);
        });
        Assert.Throws<InvalidOperationException>(() => s.Stop());
    }

    [Fact]
    public void WaitWithoutStarting()
    {
        Search s = new Search("test", (Uri result) => {
            Console.WriteLine("WaitWithoutStarting: "+result);
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


    [Fact]
    public void StartAndStopMultipleTimes()
    {
        Search s = new Search("test", (Uri result) => {
            Console.WriteLine("StartAndStopMultipleTimes: "+result);
        });
        s.Start();
        s.Stop();
        s.Start();
        s.Stop();
        s.Start();
        s.Stop();
    }
}