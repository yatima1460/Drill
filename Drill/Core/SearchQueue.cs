using System;
using System.Collections;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Drill.Core
{
    internal class SearchQueue : IEnumerable<DirectoryInfo>
    {

        readonly Queue<DirectoryInfo> _directoriesHigh = [];
        readonly Queue<DirectoryInfo> _directoriesNormal = [];
        readonly Queue<DirectoryInfo> _directoriesLow = [];

        HashSet<string> visited = [];

        public SearchQueue()
        {
            
        }


        //public DirectoryInfo this[int index] 
        //{ 
        //    get => _directories[index]; 
        //    set => _directories[index] = value; 
        //}

        public int Count => _directoriesHigh.Count+ _directoriesNormal.Count+ _directoriesLow.Count;


     
   

        public void AddHighPriority(DirectoryInfo item)
        {
            if (visited.Contains(item.FullName))
            {
                return;
            }
            _directoriesHigh.Enqueue(item);
            visited.Add(item.FullName);
        }

        internal void AddNormalPriority(DirectoryInfo item)
        {
            if (visited.Contains(item.FullName))
            {
                return;
            }
            _directoriesNormal.Enqueue(item);
            visited.Add(item.FullName);
        }

        public void AddLowPriority(DirectoryInfo item)
        {
            if (visited.Contains(item.FullName))
            {
                return;
            }
            _directoriesLow.Enqueue(item);
            visited.Add(item.FullName);
        }


        public void Clear()
        {
            _directoriesHigh.Clear();
            _directoriesNormal.Clear();
            _directoriesLow.Clear();
            visited.Clear();
        }

        private Queue<DirectoryInfo> GetHighestNotEmpty()
        {
            if (_directoriesHigh.Count != 0)
            {
                return _directoriesHigh;
            }
            if (_directoriesNormal.Count != 0)
            {
                return _directoriesNormal;
            }
            if (_directoriesLow.Count != 0)
            {
                return _directoriesLow;
            }
            return [];
        }

        public IEnumerator<DirectoryInfo> GetEnumerator()
        {
            return ((IEnumerable<DirectoryInfo>)GetHighestNotEmpty()).GetEnumerator();
        }

        IEnumerator IEnumerable.GetEnumerator()
        {
            return ((IEnumerable)GetHighestNotEmpty()).GetEnumerator();
        }


        internal DirectoryInfo PopHighestPriority()
        {
            return GetHighestNotEmpty().Dequeue();
        }

       
    }
}
