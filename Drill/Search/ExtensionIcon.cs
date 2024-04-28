using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Drill.Backend
{
    internal class ExtensionIcon
    {
        /// <summary>
        /// Given an extension returns the associated emoji for the UI
        /// </summary>
        /// <param name="extension"></param>
        /// <returns></returns>
        public static string GetIcon(string extension)
        {
            return extension switch
            {
                ".png" => "🖼️",
                ".jpg" => "🖼️",
                ".jpeg" => "🖼️",
                ".gif" => "🖼️",
                ".bmp" => "🖼️",
                ".tiff" => "🖼️",
                ".svg" => "🖼️",
                ".ico" => "🖼️",
                ".webp" => "🖼️",
                ".txt" => "📄",
                ".doc" => "📄",
                ".docx" => "📄",
                ".pdf" => "📄",
                ".xls" => "📄",
                ".xlsx" => "📄",
                ".ppt" => "📄",
                ".pptx" => "📄",
                ".csv" => "📄",
                ".zip" => "📦",
                ".rar" => "📦",
                ".tar" => "📦",
                ".gz" => "📦",
                ".7z" => "📦",
                ".mp4" => "🎥",
                ".mov" => "🎥",
                ".avi" => "🎥",
                ".mkv" => "🎥",
                ".wmv" => "🎥",
                ".flv" => "🎥",
                ".webm" => "🎥",
                ".mp3" => "🎵",
                ".wav" => "🎵",
                ".ogg" => "🎵",
                ".flac" => "🎵",
                ".aac" => "🎵",
                ".m4a" => "🎵",
                ".wma" => "🎵",
                ".mid" => "🎵",
                ".midi" => "🎵",
                ".opus" => "🎵",
                ".ape" => "🎵",
                ".ac3" => "🎵",
                ".amr" => "🎵",
                ".dts" => "🎵",
                ".pcm" => "🎵",
                ".aiff" => "🎵",
                ".alac" => "🎵",
                ".dsd" => "🎵",
                ".exe" => "⚙️",
                ".dll" => "⚙️",
                ".sys" => "⚙️",
                ".bat" => "⚙️",
                ".sh" => "⚙️",
                ".cmd" => "⚙️",
                ".com" => "⚙️",
                ".css" => "📝",
                ".html" => "📝",
                ".js" => "📝",
                ".json" => "📝",
                ".xml" => "📝",
                ".cpp" => "📝",
                ".h" => "📝",
                ".cs" => "📝",
                ".java" => "📝",
                ".py" => "📝",
                ".rb" => "📝",
                ".php" => "📝",
                ".sql" => "📝",
                ".pl" => "📝",
                ".swift" => "📝",
                ".kt" => "📝",
                ".go" => "📝",
                _ => "❓",
            };
        }
    }
}
