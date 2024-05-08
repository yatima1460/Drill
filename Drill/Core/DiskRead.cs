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


        public static FileInfo[] SafeGetFilesInDirectory(DirectoryInfo directoryInfo)
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


        public static DirectoryInfo[] SafeGetDirectoriesInDirectory(DirectoryInfo directoryInfo)
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
            return await Task.Run(() => SafeGetFilesInDirectory(directoryInfo));
        }

        public static async Task<DirectoryInfo[]> GetDirectoriesInDirectoryAsync(DirectoryInfo directoryInfo)
        {
            // Run the synchronous file operation in a background task
            return await Task.Run(() => SafeGetDirectoriesInDirectory(directoryInfo));
        }
    }
}
