

namespace Drill.Core
{
    public readonly struct DrillResult
    {
        public required string Icon { get; init; }
        public required string Name { get; init; }
        public required string Path { get; init; }
        public required string Date { get; init; }
        public required string Size { get; init; }
        public required string FullPath { get; init; }

        public override int GetHashCode()
        {
            return FullPath.GetHashCode();
        }

        public override string? ToString()
        {
            return FullPath;
        }
    }
}
