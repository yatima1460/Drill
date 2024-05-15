

using System.Diagnostics;


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
                Debug.WriteLine(e);
                return [];
            }
        }
    }
}
