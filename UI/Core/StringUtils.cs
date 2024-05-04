using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Core
{
    internal static class StringUtils
    {

        internal static readonly ConcurrentDictionary<Tuple<string, string>, bool> tokenCache = new();

        internal static bool TokenMatching(string searchString, string fileName)
        {
            
            var pair = new Tuple<string,string>(searchString, fileName);
            if (tokenCache.TryGetValue(pair, out bool value))
            {
                return value;
            }
          

            string[] tokenizedSearchString = searchString.Split(" ");
            foreach (string token in tokenizedSearchString)
            {
                if (!fileName.Contains(token, StringComparison.InvariantCultureIgnoreCase))
                {
                    tokenCache[pair] = false;
                    return false;
                }
            }
            tokenCache[pair] = true;
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
