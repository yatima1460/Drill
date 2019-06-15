import DrillGTK.Window : DrillWindow;

import std.concurrency;
import std.stdio : writeln;
import std.path : baseName, dirName, extension, buildNormalizedPath, absolutePath;

import gtk.Application : Application;
import gio.Application : GioApplication = Application;
import gtk.Application : GApplicationFlags;

int main(string[] args)
{
    Application application = new Application("me.santamorena.drill", GApplicationFlags.FLAGS_NONE);
    application.addOnActivate(delegate void(GioApplication app) {
        new DrillWindow(args[0], application);
    });
    return application.run(args);
}
