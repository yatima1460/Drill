
using System.Collections.Immutable;

using System.Reflection;


namespace Drill.Core
{
    internal static class Heuristics
    {
        // Very heavy Win32 call, cache it
        private static readonly string UserName = Environment.UserName;

        static readonly ImmutableHashSet<string> dict;

        static Heuristics()
        {
            string? path = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
            if (path == null)
            {
                Console.WriteLine("Executing assembly path is null???");
                dict = [];
                return;
            }
            var DictPath = Path.Combine(path, "words_alpha.txt");
            if (!File.Exists(DictPath))
            {
                Console.WriteLine("Can't find words dictionary");
                dict = [];
                return;
            }
            dict = [.. File.ReadAllLines(DictPath)];
        }



        public static HeuristicsDirectoryPriority GetDirectoryPriority(in DirectoryInfo sub, in string searchString)
        {
            // All main drives are very important besides C:
            if (sub.Parent == null)
            {
                // all folders in C: are generally system related
                if (sub.FullName == "C:\\")
                    return HeuristicsDirectoryPriority.SystemOrHiddenOrToolRelated;
                // Other drives are for sure used by humans
                return HeuristicsDirectoryPriority.UsedByAHuman;
            }

            if (sub.Name == "node_modules"
            || (sub.Attributes & FileAttributes.Temporary) == FileAttributes.Temporary
            || sub.Name.Equals("cache", StringComparison.CurrentCultureIgnoreCase)
            || sub.Name.Equals("tmp", StringComparison.CurrentCultureIgnoreCase)
             || sub.Name.Equals("temp", StringComparison.CurrentCultureIgnoreCase)
             // If the folder is deep inside an hidden folder  
             || sub.FullName.Contains(Path.DirectorySeparatorChar + ".")
            )
            {
                return HeuristicsDirectoryPriority.TemporaryOrCache;
            }


            if ((sub.Attributes & FileAttributes.Hidden) == FileAttributes.Hidden
            // strange system folders
            || (sub.Attributes & FileAttributes.System) == FileAttributes.System
              // all hidden folders 
              || sub.Name.StartsWith(".")
            // Windows is a no-no
            || sub.FullName.StartsWith("C:\\Windows")
            // often full of garbage
            || sub.FullName.StartsWith($"C:\\Users\\{UserName}\\AppData")
            || sub.FullName.Contains(Path.DirectorySeparatorChar + ".")
            )
            {
                return HeuristicsDirectoryPriority.SystemOrHiddenOrToolRelated;
            }

           

            if (sub.FullName == $"/Users/{UserName}/Library/Mobile Documents/com~apple~CloudDocs/")
            {
                return HeuristicsDirectoryPriority.UsedByAHuman;
            }

            // Cutoff: if the folder is very deep it's unknown priority and never high
            if (sub.FullName.Split(Path.DirectorySeparatorChar, StringSplitOptions.RemoveEmptyEntries).Length > 6)
            {
                return HeuristicsDirectoryPriority.Unknown;
            }

            if (
               // folder contains search string
               StringUtils.TokenMatching(searchString, sub.Name))

            {
                return HeuristicsDirectoryPriority.PossiblyCreatedByAHuman;
            }

         
            

            if (
             // user folder
             sub.FullName == $"C:\\Users\\{UserName}"
             // all folders in the user folder
             || sub.Parent != null && sub.Parent.FullName == $"C:\\Users\\{UserName}"
             // If folder contains the username it's generally very important
             || sub.Name.ToLower().Contains(UserName.ToLower())
            // If folder is inside a folder with the username it's generally very important
             || sub.Parent.Name.ToLower().Contains(UserName.ToLower())
            )
            {
                return HeuristicsDirectoryPriority.UsedByAHuman;
            }


            // If name is long and does not contain spaces or separating characters it's generally something from a tool
            if (sub.Name.Length > 16 && !sub.Name.Contains('-') && !sub.Name.Contains(' ') && !sub.Name.Contains('_'))
            {
                return HeuristicsDirectoryPriority.SystemOrHiddenOrToolRelated;
            }

            // english dictionary
            //foreach (string wordInTheFullPath in sub.FullName.ToLower().Split(separator: (char[])[Path.DirectorySeparatorChar, ' ','-','_'], options: StringSplitOptions.RemoveEmptyEntries))
            //{
            //    if (dict.Contains(wordInTheFullPath)) return HeuristicsDirectoryPriority.PossiblyCreatedByAHuman;
            //}
          
            if (dict.Contains(sub.Name.ToLower())) return HeuristicsDirectoryPriority.PossiblyCreatedByAHuman;
        
            


            // Priority is normal if heuristics has no idea what to do
#if DEBUG
            Debug.WriteLine("Unknown Priority: " + sub.FullName);
#endif
            return HeuristicsDirectoryPriority.Unknown;
        }


    }
}
