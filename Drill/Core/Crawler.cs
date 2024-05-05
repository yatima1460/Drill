

//using Drill.Core;
//using System.Collections.Concurrent;




//namespace Drill.Core
//{
//    internal class Crawler
//    {
       
//        private readonly DirectoryInfo root;
//        private readonly List<string> blacklisted;
//        private readonly string searchString;


//        //private readonly FatalErrorCallback errorHandler;
//        private Thread thread;



//        public Crawler(DirectoryInfo root, string searchString, List<string> blacklisted, Search.FatalErrorCallback errorHandler)
//        {
//            this.root = root;
//            this.blacklisted = blacklisted;
//            this.searchString = searchString;
//            //this.errorHandler = errorHandler;
//            this.thread = new Thread(this.StartSync);

//        }

//        internal void StartAsync()
//        {
//            thread.Start(); 
//        }

//        internal void StartSync()
//        {

           

            
           


//        }

//        internal void StopAsync()
//        {
//            _stopRequested = true;
//        }

//        internal void Wait()
//        {
//            thread.Join();
//            ParallelResults.Clear();
//        }

//        public List<DrillResult> PopResults(int count)
//        {
//            if (_stopRequested)
//            {
//                return [];
//            }
//            int minSize = Math.Min(count, ParallelResults.Count);
//            List<DrillResult> results = new(minSize);
//            for (int i = 0; i < minSize; i++)
//            {
//                if (ParallelResults.TryDequeue(out DrillResult result))
//                {
//                    results.Add(result);
//                }
//            }
//            return results;
//        }
//    }
//}
