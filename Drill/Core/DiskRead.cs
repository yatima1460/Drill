using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Drill.Core
{
    internal static class DiskRead
    {

        internal static FileSystemInfo[] SafeGetFileSystemInfosInDirectory(DirectoryInfo rootFolderInfo)
        {
            try
            {
                return rootFolderInfo.GetFileSystemInfos("*", SearchOption.TopDirectoryOnly);
            }
            catch (Exception e)
            {
                return [];
            }
        }
    }
}
