using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Drill.Core
{
    internal static class StringUtils
    {
        internal static bool TokenMatching(string searchString, string fileName)
        {
            string[] tokenizedSearchString = searchString.Split(" ");
            foreach (string token in tokenizedSearchString)
            {
                if (!fileName.Contains(token, StringComparison.InvariantCultureIgnoreCase))
                {
                    return false;
                }
            }
            return true;
        }

        internal static string GetHumanReadableSize(FileInfo fileSystemInfo)
        {
            long sizeInBytes = ((FileInfo)fileSystemInfo).Length;
            string[] sizes = ["B", "KB", "MB", "GB", "TB"];
            int order = 0;
            double size = sizeInBytes;

            while (size >= 1024 && order < sizes.Length - 1)
            {
                order++;
                size /= 1024;
            }

            return $"{size:0.#} {sizes[order]}"; // Formatting size with appropriate unit
        }
    }


}
