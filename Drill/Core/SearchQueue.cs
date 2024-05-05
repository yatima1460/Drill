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

        List<DirectoryInfo> _directoriesHigh = [];
        List<DirectoryInfo> _directoriesNormal = [];
        List<DirectoryInfo> _directoriesLow = [];


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
            _directoriesHigh.Add(item);
        }

        internal void AddNormalPriority(DirectoryInfo item)
        {
            _directoriesNormal.Add(item);
        }

        public void AddLowPriority(DirectoryInfo item)
        {
            _directoriesLow.Add(item);
        }


        public void Clear()
        {
            _directoriesHigh.Clear();
            _directoriesNormal.Clear();
            _directoriesLow.Clear();
        }

        private List<DirectoryInfo> GetHighestNotEmpty()
        {
            if (_directoriesHigh.Count != 0)
            {
                return _directoriesHigh;
            }
            if (_directoriesNormal.Count != 0)
            {
                return _directoriesNormal;
            }
            
            return _directoriesLow;
        }

        public IEnumerator<DirectoryInfo> GetEnumerator()
        {
            return ((IEnumerable<DirectoryInfo>)GetHighestNotEmpty()).GetEnumerator();
        }

        IEnumerator IEnumerable.GetEnumerator()
        {
            return ((IEnumerable)GetHighestNotEmpty()).GetEnumerator();
        }


        internal DirectoryInfo PopHighPriority()
        {
            var mostImportant = GetHighestNotEmpty();
            var r = mostImportant[0];
            mostImportant.RemoveAt(0);
            return r;
        }

       
    }
}
