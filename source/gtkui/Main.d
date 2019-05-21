import Drill.Window : DrillWindow;

import std.concurrency;
import gtk.Application : Application;
import gio.Application : GioApplication = Application;
import gtk.Application : GApplicationFlags;

int main(string[] args)
{
    // import core.memory;
    // GC.disable();
    import std.stdio : writeln;
          import std.path : baseName, dirName, extension, buildNormalizedPath, absolutePath;

  
    std.concurrency.thisTid;
    auto application = new Application("me.santamorena.drill", GApplicationFlags.FLAGS_NONE);
    application.addOnActivate(delegate void(GioApplication app) {
        new DrillWindow(args[0],application);
    });
    return application.run(args);
    
}
