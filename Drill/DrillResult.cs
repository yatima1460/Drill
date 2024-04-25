
namespace Drill.Core;
public class DrillResult {


    public string Name { get; }
    public string Path { get; }
    public string Date { get; }
    public string Size { get; }

    public string Icon { get; }
	public string FullPath { get; }

	  // Method to convert file size to human-readable format
    private static string GetHumanReadableSize(FileSystemInfo fileSystemInfo)
    {
        if ((fileSystemInfo.Attributes & FileAttributes.Directory) == FileAttributes.Directory)
        {
            
            return ""; // If it's a directory, return empty string for size
        }
        else
        {
            long sizeInBytes = ((FileInfo)fileSystemInfo).Length;
            string[] sizes = { "B", "KB", "MB", "GB", "TB" };
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
	public DrillResult(FileSystemInfo fileSystemInfo)
	{
		Name = fileSystemInfo.Name;
		FullPath = fileSystemInfo.FullName;
        Path = System.IO.Path.GetDirectoryName(fileSystemInfo.FullName); // Extracting the parent directory path
        Date = fileSystemInfo.LastWriteTime.ToString("F"); // Formatting the date with the full (long) date/time pattern
        Size = GetHumanReadableSize(fileSystemInfo); // Converting size to human-readable format
        if ((fileSystemInfo.Attributes & FileAttributes.Directory) == FileAttributes.Directory)
        {
            Icon = "📁";
        }
        else
        {
            Icon = fileSystemInfo.Extension.ToLower() switch
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