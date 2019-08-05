



import GTKBinds;
import std.container : DList;
import FileInfo : FileInfo;
import Config : DrillConfig;


struct DrillGtkContext
{
    import Context : DrillContext;
    import ApplicationInfo : ApplicationInfo;

    // import std.path : dirName, buildNormalizedPath, absolutePath, buildPath;
    // import std.string : toStringz;
    // import Context : startCrawling, DrillContext;
    // import ApplicationInfo : ApplicationInfo, getApplications;
    ApplicationInfo[] applications;
    GtkWindow* window;
    GAsyncQueue* queue;
    bool running = true;
    GtkTreeView* treeview;
    GtkListStore* liststore;
    shared(DList!FileInfo) buffer1;
    shared(DList!FileInfo) buffer2;
    shared(DList!FileInfo)* buffer;
    GtkEntry* search_input;
    DrillContext context;
    GtkLabel* credits;
    GtkApplication* app;
    DrillConfig drillConfig;

    string[string] mime;

    long oldTime;

    bool list_dirty = false;

    invariant
    {
        assert(app !is null);
    }
}


import Context : stopCrawlingAsync;

/++
    Closes the GTK application and stops the crawlers

    Params:
        context = the DrillGtkContext struct
+/
void closeApplication(DrillGtkContext* context)
in(context != null)
{
    assert(context !is null);
    g_idle_remove_by_data(context);

    /+ 
        Last opportunity to stop crawlers
        Because we stop with Async the window will close instantly,
        good for usability reasons,
        But the process will linger a bit to close the crawlers
    +/
    assert(context !is null);
    context.context.threads.stopCrawlingAsync();

    assert(context !is null);
    context.running = false;
}

