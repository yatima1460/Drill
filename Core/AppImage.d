



import std.functional : memoize;
import std.typecons : Tuple;
import std.experimental.logger;
import std.uni : toLower;
import std.path : extension;
import std.process : executeShell, Config;
import std.algorithm : filter;
import std.array : array, split;
import std.file : dirEntries, SpanMode, DirEntry, readText, FileException;



// string mountAppImage(const string path)
// {
//     auto mnt = executeShell(path ~ " --appimage-extract",null,Config.detached);
//     if (mnt.status != 0)
//     {
//         error("Can't mount AppImage: "~path);
//     }

//     return mnt.output;
// }

// void umountAppImage(const string path)
// {
//     auto mnt = executeShell("fusermount -u " ~ mountpoint);
//     if (mnt.status != 0)
//     {
//         error("Can't umount AppImage: "~mountpoint);
//     }
// }

// string getAppImageIconPath(const string mountpoint)
// {
//     auto icons = dirEntries(mountpoint, ".{png,svg,xpm}", SpanMode.shallow).array;
//     if (icons.length >= 1)
//     {
//         // TODO: read desktop file
//         return icons[0];
//     }
//     return null;
// }