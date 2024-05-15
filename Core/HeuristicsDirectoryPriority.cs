

namespace Drill.Core
{
    internal enum HeuristicsDirectoryPriority
    {
        /// <summary>
        /// The directory is for sure used by a human
        /// </summary>
        UsedByAHuman,
        /// <summary>
        /// High chance the directory is created by a human
        /// </summary>
        PossiblyCreatedByAHuman,
        /// <summary>
        /// We don't know
        /// </summary>
        Unknown,
        /// <summary>
        /// Directory is for sure system related, no one would care, normally not visible by a human
        /// </summary>
        SystemOrHiddenOrToolRelated,
        /// <summary>
        /// Directory is like a form of cache and it's completely useless
        /// </summary>
        TemporaryOrCache
    }

}
