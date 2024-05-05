//using System;
//using System.Collections.Generic;
//using System.Linq;
//using System.Text;
//using System.Threading.Tasks;

//namespace Drill.Core
//{
//    internal class SearchComparer : IComparer<DirectoryInfo>
//    {

//        public int Compare(DirectoryInfo x, DirectoryInfo y)
//        {

//            if (x.Name.StartsWith(".") && !y.Name.StartsWith("."))
//            {
//                return -1;
//            }
//            if (!x.Name.StartsWith(".") && y.Name.StartsWith("."))
//            {
//                return 1;
//            }

//            if ((x.Name.StartsWith(".") && y.Name.StartsWith(".")) || (!x.Name.StartsWith(".") && !y.Name.StartsWith(".")))
//            {
//                return 0;
//            }
//            // CompareTo() method 
//            return x.LastWriteTime.CompareTo(y.LastWriteTime);

//        }
//    }
//}
