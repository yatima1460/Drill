﻿using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Drill.Core
{
    internal static class ExtensionIcon
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
                ".torrent" => "🌐",
                ".ds_store" => "🍏",
                ".lnk" => "🔗",
                ".url" => "🔗",
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
                ".chm" => "📄",
                ".pdf" => "📄",
                ".xls" => "📄",
                ".xlsx" => "📄",
                ".ppt" => "📄",
                ".pptx" => "📄",
                ".csv" => "📄",
                ".zip" => "📦",
                ".cab" => "📦",
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
                ".bin" => "⚙️",
                ".dylib" => "⚙️",
                ".dll" => "⚙️",
                ".sys" => "⚙️",
                ".bat" => "⚙️",
                ".sh" => "⚙️",
                ".cmd" => "⚙️",
                ".com" => "⚙️",
                ".css" => "📝",
                ".nfo" => "📝",
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
                ".ini" => "📝",
                ".sql" => "📝",
                ".pl" => "📝",
                ".swift" => "📝",
                ".kt" => "📝",
                ".go" => "📝",

                // TODO: log in Debug mode when no extension
                _ => "❓",
            } ;
        }
    }
}
