

namespace Drill.Backend;
public class DrillResult
{

    public required string Name;
    public required string Path;
    public required string Date;
    public required string Size;
    public required string Icon;
    public required string FullPath;

    //public override bool Equals(object? obj)
    //{
    //    if (obj == null)
    //        return false;
    //    if (obj is not DrillResult)
    //        return false;
    //    return ((DrillResult)obj).FullPath.Equals(this.FullPath);
    //}

    //public override int GetHashCode()
    //{
    //    return FullPath.GetHashCode();
    //}

    //public override string? ToString()
    //{
    //    return FullPath;
    //}
}