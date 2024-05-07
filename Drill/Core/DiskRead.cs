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


        private static FileInfo[] _safeGetFilesInDirectory(DirectoryInfo directoryInfo)
        {
            try
            {
                return directoryInfo.GetFiles("*", SearchOption.TopDirectoryOnly);
            }
            catch (Exception e)
            {
                return [];
            }
        }


        private static DirectoryInfo[] _safeGetDirectoriesInDirectory(DirectoryInfo directoryInfo)
        {
            try
            {
                return directoryInfo.GetDirectories("*", SearchOption.TopDirectoryOnly);
            }
            catch (Exception e)
            {
                return [];
            }
        }

        public static async Task<FileInfo[]> GetFilesInDirectoryAsync(DirectoryInfo directoryInfo)
        {
            // Run the synchronous file operation in a background task
            return await Task.Run(() => _safeGetFilesInDirectory(directoryInfo));
        }

        public static async Task<DirectoryInfo[]> GetDirectoriesInDirectoryAsync(DirectoryInfo directoryInfo)
        {
            // Run the synchronous file operation in a background task
            return await Task.Run(() => _safeGetDirectoriesInDirectory(directoryInfo));
        }
    }
}
