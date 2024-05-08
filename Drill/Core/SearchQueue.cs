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
        static readonly ImmutableHashSet<string> dict;

        readonly string searchString;
        readonly static string UserName = Environment.UserName;


        HashSet<string> visited = [];

        static SearchQueue()
        {

            HashSet<string> dictMut = new();
            using var stream = FileSystem.OpenAppPackageFileAsync("words_alpha.txt").Result;
            using var reader = new StreamReader(stream);

            var contents = reader.ReadToEnd();

            foreach (var item in contents.Split("\r\n"))
            {
                dictMut.Add(item);
            }
            reader.Close();
            stream.Close();
            dict = dictMut.ToImmutableHashSet<string>();
        }

        public SearchQueue(string searchString)
        {
            this.searchString = searchString;
            foreach (SearchPriority item in Enum.GetValues(typeof(SearchPriority)))
            {
                _priorityQueue[item] = new(1000);
            }
        }


     


        public static SearchPriority GetDirectoryPriority(DirectoryInfo sub, string searchString)
        {
            // all main drives are very important besides C:
            if (sub.Parent == null)
            {
                // all folders in C: are generally useless
                if (sub.FullName == "C:\\")
                    return SearchPriority.Low;
                return SearchPriority.Highest;
            }

            if (sub.FullName == $"/Users/{UserName}/Library/Mobile Documents/com~apple~CloudDocs/")
            {
                return SearchPriority.Highest;
            }

            if (sub.FullName.ToLower() == "node_modules"
                            || (sub.Attributes & FileAttributes.Temporary) == FileAttributes.Temporary
                )
            {
                return SearchPriority.Lowest;
            }


            if (
                // all hidden folders
                sub.Name.StartsWith(".")
            || (sub.Attributes & FileAttributes.Hidden) == FileAttributes.Hidden
            // strange system folders
            || (sub.Attributes & FileAttributes.System) == FileAttributes.System

            // Windows is a no-no
            || sub.FullName.StartsWith("C:\\Windows")
            // very bad stuff
            || sub.FullName.ToLower() == "cache"
            // often full of garbage
            || sub.FullName.StartsWith($"C:\\Users\\{UserName}\\AppData")
            // If the folder is deep inside an hidden folder
            || sub.FullName.Contains(Path.DirectorySeparatorChar + ".")
            )
            {
                return SearchPriority.Low;
            }




            // Cutoff: if the folder is very deep it's normal priority and never high
            if (sub.FullName.Split(Path.DirectorySeparatorChar, StringSplitOptions.RemoveEmptyEntries).Length > 6)
            {
                return SearchPriority.Normal;
            }

            if (
               // folder contains search string
               StringUtils.TokenMatching(searchString, sub.Name))

            {
                return SearchPriority.Highest;
            }

            if (
             // user folder
             sub.FullName == $"C:\\Users\\{UserName}"
             // all folders in the user folder
             || sub.Parent != null && sub.Parent.FullName == $"C:\\Users\\{UserName}"
             // english dictionary
             || ContainsCommonWords(sub.Name)

            )
            {
                return SearchPriority.High;
            }

            // If folder contains the username it's generally very important
            if (sub.Name.ToLower().Contains(UserName.ToLower()))
            {
                return SearchPriority.High;
            }

            // If name is long and does not contain spaces or separating characters it's generally something from a tool
            if (sub.Name.Length > 16 && !sub.Name.Contains('-') && !sub.Name.Contains(' ') && !sub.Name.Contains('_'))
            {
                return SearchPriority.Low;
            }

            // Priority is normal if heuristics has no idea what to do
#if DEBUG
            // TODO: log here 
#endif
            return SearchPriority.Normal;
        }

        private static bool ContainsCommonWords(string name)
        {
            var s = name.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            foreach (var item in s)
            {
                if (dict.Contains(item.ToLower())) return true;
            }
            return false;
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

        internal void Add(DirectoryInfo item, SearchPriority priority)
        {
            if (visited.Contains(item.FullName))
            {
                return;
            }
            _priorityQueue[priority].Enqueue(item);
            visited.Add(item.FullName);
        }

        public void Add(DirectoryInfo item)
        {
            Add(item, GetDirectoryPriority(item, searchString));
        }

        internal void Add(string v)
        {
            Add(new DirectoryInfo(v));
        }

        internal void Add(Environment.SpecialFolder specialFolder)
        {
            Add(Environment.GetFolderPath(specialFolder));
        }

    }
}
