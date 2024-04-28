using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Drill.Core
{
    internal class StringUtils
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
    }
}
