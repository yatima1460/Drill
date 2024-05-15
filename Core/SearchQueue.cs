

using System.Diagnostics;

namespace Drill.Core
{
    internal class SearchQueue
    {
        readonly Dictionary<HeuristicsDirectoryPriority, Queue<DirectoryInfo>> priorityQueue = new(1000);
        readonly string searchString;
        readonly HashSet<string> visited = new(1000);

        public SearchQueue(in string searchString)
        {
            this.searchString = searchString;
            foreach (HeuristicsDirectoryPriority item in Enum.GetValues(typeof(HeuristicsDirectoryPriority)))
            {
                priorityQueue[item] = new(1000);
            }
        }

        public void Clear()
        {
            priorityQueue.Clear();
            visited.Clear();
        }

        private Queue<DirectoryInfo> GetHighestNotEmpty()
        {
            foreach (HeuristicsDirectoryPriority item in Enum.GetValues(typeof(HeuristicsDirectoryPriority)))
            {
                if (priorityQueue[item].Count > 0)
                {
                    return priorityQueue[item];
                }
            }
            return [];
        }

        internal bool PopHighestPriority(out DirectoryInfo? result)
        {
            var flag = GetHighestNotEmpty().TryDequeue(out DirectoryInfo? result2);
            result = result2;
            return flag;
        }

        internal void Add(in DirectoryInfo item, in HeuristicsDirectoryPriority priority)
        {
            if (visited.Contains(item.FullName))
            {
                return;
            }
            priorityQueue[priority].Enqueue(item);
            visited.Add(item.FullName);
        }

        public void Add(in DirectoryInfo item)
        {
            Add(item, Heuristics.GetDirectoryPriority(item, searchString));
        }

        internal void Add(in string FullPath)
        {
            try
            {
                Add(new DirectoryInfo(FullPath));
            }
            catch (Exception e)
            {
                Debug.WriteLine(e);
            }
        }

        internal void Add(in Environment.SpecialFolder specialFolder)
        {
            try
            {
                Add(Environment.GetFolderPath(specialFolder));
            }
            catch (Exception e)
            {
                Debug.WriteLine(e);
            }
        }

    }
}
