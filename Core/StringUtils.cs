﻿
using System.Collections.Concurrent;

namespace Drill.Core
{
    public static class StringUtils
    {

        internal static readonly ConcurrentDictionary<Tuple<string, string>, bool> tokenCache = [];

        internal static bool TokenMatching(in string searchString, in string fileName)
        {
            
            var pair = new Tuple<string,string>(searchString, fileName);
            if (tokenCache.TryGetValue(pair, out bool value))
            {
                return value;
            }
          

            string[] tokenizedSearchString = searchString.Split(" ", StringSplitOptions.RemoveEmptyEntries);
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

        static readonly string[] sizes = [" B", "KB", "MB", "GB", "TB"];

        public static string GetHumanReadableSize(in long sizeInBytes)
        {
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
