using System;
using System.Collections;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.IO;
using System.Linq;
using System.Reflection.PortableExecutable;
using System.Text;
using System.Threading.Tasks;

namespace Drill.Core
{
    internal class SearchQueue : IEnumerable<DirectoryInfo>
    {

        readonly Queue<DirectoryInfo> _directoriesHigh = [];
        readonly Queue<DirectoryInfo> _directoriesNormal = [];
        readonly Queue<DirectoryInfo> _directoriesLow = [];
        static readonly HashSet<string> dict = new HashSet<string>();

        readonly string searchString;
        readonly static string UserName = Environment.UserName;

        HashSet<string> visited = [];

        static SearchQueue()
        {

            using var stream = FileSystem.OpenAppPackageFileAsync("words_alpha.txt").Result;
            using var reader = new StreamReader(stream);

            var contents = reader.ReadToEnd();

            foreach (var item in contents.Split("\r\n"))
            {
                if (item.Length > 4)
                    dict.Add(item);

            }
        }

        public SearchQueue(string searchString)
        {
            this.searchString = searchString;
        }


        public void Add(DirectoryInfo item, SearchPriority priority)
        {
            switch (priority)
            {
                case SearchPriority.Low:
                    AddLowPriority(item);
                    break;
                case SearchPriority.Normal:
                    AddNormalPriority(item);
                    break;
                case SearchPriority.High:
                    AddHighPriority(item);
                    break;
            }
        }

        public void Add(DirectoryInfo item)
        {
            switch (GetDirectoryPriority(item, searchString))
            {
                case SearchPriority.Low:
                    AddLowPriority(item);
                    break;
                case SearchPriority.Normal:
                    AddNormalPriority(item);
                    break;
                case SearchPriority.High:
                    AddHighPriority(item);
                    break;
            }
        }



        public static SearchPriority GetDirectoryPriority(DirectoryInfo sub, string searchString)
        {
            if (
                sub.Name.StartsWith(".")
            || (sub.Attributes & FileAttributes.Hidden) == FileAttributes.Hidden
            || (sub.Attributes & FileAttributes.System) == FileAttributes.System
            || (sub.Attributes & FileAttributes.Temporary) == FileAttributes.Temporary
            || sub.FullName.StartsWith("C:\\Windows")
            || sub.FullName.StartsWith($"C:\\Users\\{UserName}\\AppData")
            || (sub.Parent != null && sub.Parent.FullName == "C:\\")
            || (sub.Attributes & FileAttributes.ReparsePoint) == FileAttributes.ReparsePoint
            )
            {
                return SearchPriority.Low;
            }


            // If very deep it's normal by default
            if (sub.FullName.Split(Path.DirectorySeparatorChar, StringSplitOptions.RemoveEmptyEntries).Length > 6)
            {
                return SearchPriority.Normal;
            }

                if (
                StringUtils.TokenMatching(searchString, sub.Name)
             || dict.Contains(sub.Name.ToLower())
             || sub.FullName == $"C:\\Users\\{UserName}"
             || (sub.Parent != null && sub.Parent.FullName == $"C:\\Users\\{UserName}")
            )
            {
                return SearchPriority.High;
            }

            return SearchPriority.Normal;

        }


        //public DirectoryInfo this[int index] 
        //{ 
        //    get => _directories[index]; 
        //    set => _directories[index] = value; 
        //}

        public int Count => _directoriesHigh.Count + _directoriesNormal.Count + _directoriesLow.Count;





        private void AddHighPriority(DirectoryInfo item)
        {
            if (visited.Contains(item.FullName))
            {
                return;
            }
            _directoriesHigh.Enqueue(item);
            visited.Add(item.FullName);
        }

        private void AddNormalPriority(DirectoryInfo item)
        {
            if (visited.Contains(item.FullName))
            {
                return;
            }
            _directoriesNormal.Enqueue(item);
            visited.Add(item.FullName);
        }

        private void AddLowPriority(DirectoryInfo item)
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
