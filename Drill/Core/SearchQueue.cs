using Microsoft.UI.Xaml.Controls;
using System;
using System.Collections;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Collections.Immutable;
using System.Collections.ObjectModel;
using System.IO;
using System.Linq;
using System.Reflection.PortableExecutable;
using System.Text;
using System.Threading.Tasks;

namespace Drill.Core
{
    internal class SearchQueue
    {



        readonly Dictionary<SearchPriority, Queue<DirectoryInfo>> _priorityQueue = [];


        readonly string searchString;
        HashSet<string> visited = [];

    

        public SearchQueue(in string searchString)
        {
            this.searchString = searchString;
            foreach (SearchPriority item in Enum.GetValues(typeof(SearchPriority)))
            {
                _priorityQueue[item] = new(1000);
            }
        }


     


        //public DirectoryInfo this[int index] 
        //{ 
        //    get => _directories[index]; 
        //    set => _directories[index] = value; 
        //}








        public void Clear()
        {
            _priorityQueue.Clear();
            visited.Clear();
        }

        private Queue<DirectoryInfo> GetHighestNotEmpty()
        {
            foreach (SearchPriority item in Enum.GetValues(typeof(SearchPriority)))
            {
                if (_priorityQueue[item].Count > 0)
                {
                    return _priorityQueue[item];
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

        internal void Add(in DirectoryInfo item, in SearchPriority priority)
        {
            if (visited.Contains(item.FullName))
            {
                return;
            }
            _priorityQueue[priority].Enqueue(item);
            visited.Add(item.FullName);
        }

        public void Add(in DirectoryInfo item)
        {
            Add(item, Heuristics.GetDirectoryPriority(item, searchString));
        }

        internal void Add(in string v)
        {
            Add(new DirectoryInfo(v));
        }

        internal void Add(in Environment.SpecialFolder specialFolder)
        {
            Add(Environment.GetFolderPath(specialFolder));
        }

    }
}
