
/*
    All GTK binds needed to show the UI
*/
extern (C) @trusted @nogc nothrow
{
    void g_async_queue_unref(GAsyncQueue*);

    struct GtkEntry;

    int gtk_init_check(int* argc, char*** argv);
    int gtk_main_iteration_do(int);
    void* G_CALLBACK(void*);

    enum GdkGravity
    {
        GDK_GRAVITY_NORTH_WEST,
        GDK_GRAVITY_NORTH,
        GDK_GRAVITY_NORTH_EAST,
        GDK_GRAVITY_WEST,
        GDK_GRAVITY_CENTER,
        GDK_GRAVITY_EAST,
        GDK_GRAVITY_SOUTH_WEST,
        GDK_GRAVITY_SOUTH,
        GDK_GRAVITY_SOUTH_EAST,
        GDK_GRAVITY_STATIC
    };

    struct GObject;
    enum GConnectFlags
    {
        G_CONNECT_AFTER,
        G_CONNECT_SWAPPED
    };
    void g_signal_connect_data(void* instance, const char* detailed_signal, void* c_handler, void* data, void* destroy_data, GConnectFlags connect_flags);

    int gdk_screen_width();
    int gdk_screen_height();

    struct GtkWidget;
    GObject* G_OBJECT(GtkWidget*);
    void gtk_widget_set_size_request(GtkWidget*, int, int);
    void gtk_widget_show_all(GtkWidget*);

    enum GtkWindowType
    {
        GTK_WINDOW_TOPLEVEL,
        GTK_WINDOW_POPUP
    };

    enum GtkWindowPosition
    {
        GTK_WIN_POS_NONE,
        GTK_WIN_POS_CENTER,
        GTK_WIN_POS_MOUSE,
        GTK_WIN_POS_CENTER_ALWAYS,
        GTK_WIN_POS_CENTER_ON_PARENT
    }

    struct GtkWindow;
    struct GtkBuilder;

    void g_application_quit(GtkApplication*);

    GtkWindow* GTK_WINDOW(GtkWidget*);
    GtkWindow* gtk_window_new(GtkWindowType);
    void gtk_window_set_gravity(GtkWindow*, GdkGravity);
    void gtk_window_set_title(GtkWindow*, const char*);
    void gtk_window_set_default_size(GtkWindow*, int, int);
    void gtk_window_set_default_geometry(GtkWindow* window, int width, int height);
    void gtk_window_set_resizable(GtkWindow*, bool);
    void gtk_window_set_decorated(GtkWindow*, bool);
    void gtk_window_fullscreen(GtkWindow*);
    void gtk_window_unfullscreen(GtkWindow*);
    void gtk_window_set_position(GtkWindow*, GtkWindowPosition);
    void gtk_window_move(GtkWindow* window, int x, int y);
    void gtk_window_set_keep_above(GtkWindow* w, bool);

    immutable(int) GDK_KEY_Escape = 0xff1b;

    enum GdkEventType
    {
        GDK_NOTHING = -1,
        GDK_DELETE = 0,
        GDK_DESTROY = 1,
        GDK_EXPOSE = 2,
        GDK_MOTION_NOTIFY = 3,
        GDK_BUTTON_PRESS = 4,
        GDK_2BUTTON_PRESS = 5,
        GDK_DOUBLE_BUTTON_PRESS = GDK_2BUTTON_PRESS,
        GDK_3BUTTON_PRESS = 6,
        GDK_TRIPLE_BUTTON_PRESS = GDK_3BUTTON_PRESS,
        GDK_BUTTON_RELEASE = 7,
        GDK_KEY_PRESS = 8,
        GDK_KEY_RELEASE = 9,
        GDK_ENTER_NOTIFY = 10,
        GDK_LEAVE_NOTIFY = 11,
        GDK_FOCUS_CHANGE = 12,
        GDK_CONFIGURE = 13,
        GDK_MAP = 14,
        GDK_UNMAP = 15,
        GDK_PROPERTY_NOTIFY = 16,
        GDK_SELECTION_CLEAR = 17,
        GDK_SELECTION_REQUEST = 18,
        GDK_SELECTION_NOTIFY = 19,
        GDK_PROXIMITY_IN = 20,
        GDK_PROXIMITY_OUT = 21,
        GDK_DRAG_ENTER = 22,
        GDK_DRAG_LEAVE = 23,
        GDK_DRAG_MOTION = 24,
        GDK_DRAG_STATUS = 25,
        GDK_DROP_START = 26,
        GDK_DROP_FINISHED = 27,
        GDK_CLIENT_EVENT = 28,
        GDK_VISIBILITY_NOTIFY = 29,
        GDK_SCROLL = 31,
        GDK_WINDOW_STATE = 32,
        GDK_SETTING = 33,
        GDK_OWNER_CHANGE = 34,
        GDK_GRAB_BROKEN = 35,
        GDK_DAMAGE = 36,
        GDK_TOUCH_BEGIN = 37,
        GDK_TOUCH_UPDATE = 38,
        GDK_TOUCH_END = 39,
        GDK_TOUCH_CANCEL = 40,
        GDK_TOUCHPAD_SWIPE = 41,
        GDK_TOUCHPAD_PINCH = 42,
        GDK_EVENT_LAST /* helper variable for decls */
    }

    struct GdkWindow;
    void gtk_init(int* argc, char*** argv);
    GtkBuilder* gtk_builder_new();

    guint gtk_builder_add_from_file(GtkBuilder* builder, const gchar* filename, GError** error);

    struct GError
    {
        uint domain;
        int code;
        char* message;
    };

    void g_printerr(const gchar* format, ...);
    void g_clear_error(GError** err);

    struct GtkEditable;
    gchar* gtk_editable_get_chars(GtkEditable* editable, gint start_pos, gint end_pos);

    GObject* gtk_builder_get_object(GtkBuilder* builder, const gchar* name);

    void g_signal_connect(void* instance, const char* detailed_signal, void* c_handler, void* data)
    {
        g_signal_connect_data(instance, detailed_signal, c_handler, data, null, GConnectFlags.G_CONNECT_AFTER);
    }

    void gtk_main();
    void gtk_main_quit();

    GtkApplication* gtk_application_new(const gchar* application_id, GApplicationFlags flags);

    int g_application_run(GApplication* application, int argc, char** argv);

    struct GApplication;

    void g_object_unref(gpointer object);
}



import TreeIter : GtkTreeIter;
import TreeView : GtkTreeView;
import ListStore : GtkListStore;

import Types;

extern (C) void window_destroy(GtkWindow* window, gpointer data)
in(window != null)
in(data != null)
{
    import core.stdc.stdio : printf;
    import Context : stopCrawlingSync;

    DrillGtkContext* context = cast(DrillGtkContext*) data;
    assert(context !is null);

    // Last opportunity to stop crawlers
    assert(context !is null);
    if (context.context !is null)
        (*context.context).stopCrawlingSync();

    assert(context !is null);
    context.running = false;

    assert(context !is null);
    assert(context.app !is null);
    g_application_quit(context.app);
}

extern (C) bool check_escape(GtkWidget* widget, GdkEventKey* event, gpointer data)
in(widget != null)
in(data != null)
{
    import core.stdc.stdio : printf;
    import Context : stopCrawlingSync;

    DrillGtkContext* context = cast(DrillGtkContext*) data;
    assert(context !is null);

    if (event.keyval == GDK_KEY_Escape)
    {
        assert(context !is null);

        if (context.context !is null)
        {
            (*context.context).stopCrawlingSync();
            context.context = null;
        }

        context.running = false;

        assert(context !is null);
        assert(context.app !is null);
        g_application_quit(context.app);
        return true;
    }
    return false;
}






extern (C) @nogc @trusted nothrow
{

    void gtk_widget_destroy(GtkWidget*);
    void gtk_window_set_application(GtkWindow* self, GtkApplication* application);
    alias GSourceFunc = void*;
    struct GAsyncQueue;
    guint g_idle_add(GSourceFunc func, gpointer data);
    guint g_timeout_add(guint interval, GSourceFunc func, gpointer data);
    
    gpointer g_async_queue_try_pop(GAsyncQueue* queue);
    GAsyncQueue* g_async_queue_new();

    guint gtk_builder_add_from_string(GtkBuilder* builder, const gchar* buffer, ulong length, GError** error);

    struct GdkEventKey
    {
        GdkEventType type;
        GdkWindow* window;
        gint8 send_event;
        guint32 time;
        guint state;
        guint keyval;
        gint length;
        gchar* string;
        guint16 hardware_keycode;
        guint8 group;
        bool is_modifier;
    };

    struct GtkApplication;
    enum GApplicationFlags
    {
        G_APPLICATION_FLAGS_NONE
    }
    struct GtkLabel;
    void gtk_label_set_markup(GtkLabel* label, const gchar* str);
    void g_async_queue_push(GAsyncQueue* queue, gpointer data);
    void gtk_widget_queue_draw(GtkWidget*);
    struct GtkTreePath;
    struct GtkTreeViewColumn;
    struct GtkTreeModel;
    GtkTreeModel* gtk_tree_view_get_model(GtkTreeView*);
    gboolean gtk_tree_model_get_iter(GtkTreeModel*, GtkTreeIter*, GtkTreePath*);
    void gtk_tree_model_get(GtkTreeModel*, GtkTreeIter*, ...);
}

import FileInfo : FileInfo;

void resultFound(immutable(FileInfo) result, void* userObject)
in(userObject !is null)
{
    import core.memory;
    import ListStore : appendFileInfo;
    import core.memory : GC;

    DrillGtkContext* tuple = cast(DrillGtkContext*) userObject;
    assert(tuple !is null);
    assert(tuple.queue !is null);

    // The FileInfo pointer is entering C domain so
    // we need to tell the GC to ignore it for now
    FileInfo* f = new FileInfo();
    GC.addRoot(f);
    *f = result;

    g_async_queue_push(tuple.queue, f);
}




// extern (C) gtk_list_store_get_iter()

extern (C) void row_activated(GtkTreeView* tree_view, GtkTreePath* path, GtkTreeViewColumn* column, gpointer userObject)
in(tree_view !is null)
in(path !is null)
in(column !is null)
in(userObject !is null)
{
    import std.string : fromStringz;
    import std.path : chainPath;
    import std.array : array, split;
    import std.conv : to;
    import core.stdc.stdio : printf;
    import Utils : openFile;
    import std.process : spawnProcess;
    import std.process : Config;
    import Utils : cleanExecLine;

    DrillGtkContext* context = cast(DrillGtkContext*) userObject;
    assert(context !is null);

    

    char* cname;
    char* cpath;

    GtkTreeIter iter;
    assert(tree_view !is null);
    GtkTreeModel* model = gtk_tree_view_get_model(tree_view);
    assert(model !is null);
    assert(path !is null);

    if (gtk_tree_model_get_iter(model, &iter, path))
    {
        gtk_tree_model_get(model, &iter, 1, &cname, 2, &cpath, -1);
        assert(cname !is null);
        assert(cpath !is null);
    }
    else
    {
        assert(0);
    }

    immutable(string) chained = to!string(chainPath(fromStringz(cpath), fromStringz(cname)).array);
    try
    {
        openFile(chained);
    }
    catch (Exception e)
    {
        spawnProcess(cleanExecLine(to!string(fromStringz(cpath))), null, Config.none, null);
        //  openFile(fromStringz());

        // MessageDialog d = new MessageDialog(context.window, GtkDialogFlags.MODAL, MessageType.ERROR,
        //         ButtonsType.OK, "Error opening file `" ~ chained ~ "`\n" ~ e.msg);
        // d.run();
        // d.destroy();
    }
}






extern (C) void gtk_search_changed(in GtkEditable* widget, void* userObject)
in(widget !is null)
in(userObject !is null)
{
    import std.stdio : writeln;
    import Context : DrillContext, startCrawling, stopCrawlingSync, stopCrawlingAsync;
    import Config : loadData;
    import std.file : thisExePath;
    import TreeView : clean;
    import std.conv : to;
    import TreeView : GtkTreeModel;
    import core.stdc.stdio : printf;
    import ListStore : gtk_list_store_clear;

    DrillGtkContext* context = cast(DrillGtkContext*) userObject;
    assert(context !is null);

    // If there is a Drill search going on stop it
    assert(context !is null);
    if (context.context !is null)
    {
        stopCrawlingSync(*context.context);
        context.context = null;
    }

    // Create new buffers
    context.buffer1 = DList!FileInfo();
    context.buffer2 = DList!FileInfo();
    context.buffer = &context.buffer1;

    // Get input string in the search text field
    assert(widget !is null);
    char* str = gtk_editable_get_chars(cast(GtkEditable*) widget, 0, -1);
    assert(str !is null);
    const(string) searchString = to!string(str);

    // Clean the list
    assert(context !is null);
    assert(context.liststore !is null);
    //TODO: free old context.liststore here
    assert(context !is null);
    assert(context.treeview !is null);
    const(GtkTreeModel*) newStore = context.treeview.clean();
    assert(newStore !is null);
    context.liststore = cast(GtkListStore*) newStore;
    assert(context.liststore !is null);

    
    g_async_queue_unref(context.queue);
    context.queue = g_async_queue_new();
    

    // If the search box is not empty
    if (searchString.length > 0)
    {
        // Start new crawling
        assert(context !is null);
        assert(context.context is null);
        context.context = startCrawling(context.drillConfig, searchString, &resultFound, context);
        assert(context.context !is null);
    }

    import core.memory : GC;
    //GC.collect();

    import std.stdio : writeln;
    import Utils : sizeToHumanReadable;
    writeln(GC.stats.usedSize.sizeToHumanReadable);
}

import std.container.dlist : DList;

extern (C) gboolean check_async_queue(gpointer user_data)
in(user_data !is null)
{
    import ListStore : appendFileInfo;

    DrillGtkContext* context = cast(DrillGtkContext*) user_data;
    assert(context !is null);

    // Get the next FileInfo in queue
    assert(context !is null);
    assert(context.queue !is null);


    gpointer queue_data;
    
    // If there is some data add it to the UI

    // Add a maximum of ~20 elements at a time to prevent GTK from lagging
    uint frameCutoff = 20;
    while(frameCutoff-- && (queue_data = g_async_queue_try_pop(context.queue)) != null)
    {
        FileInfo* fi = cast(FileInfo*) queue_data;
        assert(fi !is null);

        assert(context !is null);
        assert(context.liststore !is null);
        assert(fi !is null);
        appendFileInfo(context.liststore,*fi);

        import core.memory : GC;
        GC.removeRoot(fi);
    }

    // Note: if this function returns false GTK will stop queueing it
    return context.running;
}



extern (C) void activate(GtkApplication* app, gpointer userObject)
in(app !is null)
in(userObject != null)
{
    import std.file : thisExePath;
    import TreeView : gtk_tree_view_set_model;
    import TreeView : GtkTreeModel;
    import core.stdc.stdio : printf;
    import ListStore : gtk_list_store_clear;
    import std.string : toStringz;
    import ApplicationInfo : getApplications;
    import std.path : buildPath;
    import std.path : dirName;
    import ListStore : appendApplication;

    DrillGtkContext* context = cast(DrillGtkContext*) userObject;
    assert(context !is null);

    GError* error = null;

    // Initialize the .glade loader
    GtkBuilder* builder = gtk_builder_new();
    assert(builder !is null);

    // Load the UI from file
    assert(builder !is null);
    assert(error is null);
    assert(thisExePath !is null);

    immutable(char)* builderFile = toStringz(buildPath(dirName(thisExePath), "Assets/ui.glade"));
    if (builder.gtk_builder_add_from_file(builderFile, &error) == 0)
    {
        assert(error !is null);
        g_printerr("Error loading file: %s\n", error.message);
        assert(error !is null);
        g_clear_error(&error);
        assert(false, "glade file not found");
    }
    // builderFile.destroy();

    // Get the main window object from the .glade file
    assert(context !is null);
    assert(builder !is null);
    assert(context.window is null);
    context.window = cast(GtkWindow*) builder.gtk_builder_get_object("window");
    assert(context.window !is null);

    // Set debug title if debug version
    debug
    {
        assert(context !is null);
        assert(context.window !is null);
        context.window.gtk_window_set_title("Drill (DEBUG VERSION)");
    }

    // Connect the GTK window to the application
    assert(context !is null);
    assert(context.window !is null);
    assert(app !is null);
    context.window.gtk_window_set_application(app);

    // Event when the window is closed using the [X]
    assert(context !is null);
    assert(context.window !is null);
    assert(&window_destroy !is null);
    assert(app !is null);
    context.window.g_signal_connect("destroy", &window_destroy, context);

    /* Event when a key is pressed:
        - Used to check Escape to close
        - Return/Enter to start the selected result 
    */
    assert(context !is null);
    assert(context.window !is null);
    assert(&check_escape !is null);
    assert(app !is null);
    context.window.g_signal_connect("key_press_event", &check_escape, context);

    // Load default empty list
    assert(context !is null);
    assert(builder !is null);
    assert(context.liststore is null);
    context.liststore = cast(GtkListStore*) builder.gtk_builder_get_object("liststore");
    assert(context.liststore !is null);

    // Create async queue for Drill threads to put their results into
    assert(context !is null);
    assert(context.queue is null);
    context.queue = g_async_queue_new();
    assert(context.queue !is null);

    // Add task on main thread to fetch results from Drill threads
    assert(context !is null);
    assert(&check_async_queue !is null);
    g_timeout_add(16,&check_async_queue, context);

    // Load default empty TreeView
    assert(context !is null);
    assert(context.treeview is null);
    context.treeview = cast(GtkTreeView*) gtk_builder_get_object(builder, "treeview");
    assert(context.treeview !is null);

    // Event when double-click on a row
    assert(context !is null);
    assert(context.treeview !is null);
    g_signal_connect(context.treeview, "row-activated", &row_activated, context);

    // Set empty ListStore to the TreeView
    assert(context !is null);
    assert(context.treeview !is null);
    assert(context.liststore !is null);
    context.treeview.gtk_tree_view_set_model(cast(GtkTreeModel*) context.liststore);

    // Load search entry from UI file
    assert(context !is null);
    assert(context.search_input is null);
    assert(builder !is null);
    context.search_input = cast(GtkEntry*) builder.gtk_builder_get_object("search_input");
    assert(context.search_input !is null);

    // Event when something is typed in the search box

    assert(context !is null);
    assert(&gtk_search_changed !is null);
    assert(context.search_input !is null);
    context.search_input.g_signal_connect("changed", &gtk_search_changed, context);

    // Load bottom credits label
    assert(context !is null);
    assert(context.credits is null);
    context.credits = cast(GtkLabel*) gtk_builder_get_object(builder, "credits");
    assert(context.credits !is null);

    // Add default apps
    foreach (application; getApplications())
    {
        assert(context !is null);
        assert(context.liststore !is null);
        context.liststore.appendApplication(application);
    }

    // Set bottom credits label
    import Meta : GITHUB_URL, AUTHOR_URL, AUTHOR_NAME, VERSION;
    import std.conv : to;
    import std.compiler : name, vendor, version_major, version_minor, D_major;

    debug
    {
        immutable(string) COMPILER_META = " " ~ name ~ " Compiler Vendor: " ~ to!string(
                vendor) ~ " Compiler version: v" ~ to!string(version_major) ~ "." ~ to!string(
                version_minor) ~ " D version:" ~ to!string(D_major);
    }
    else
    {
        immutable(string) COMPILER_META = "";
    }

    version (LDC) immutable(string) COMPILER = "LLVM " ~ COMPILER_META;
    version (DigitalMars) immutable(string) COMPILER = "DMD" ~ COMPILER_META;
    version (GNU) immutable(string) COMPILER = "GNU" ~ COMPILER_META;
    version (SDC) immutable(string) COMPILER = "SDC" ~ COMPILER_META;

    assert(context !is null);
    assert(context.credits !is null);
    (cast(GtkLabel*) context.credits).gtk_label_set_markup(toStringz(
            "<a href=\"" ~ GITHUB_URL ~ "\">Drill</a>" ~ " is maintained by " ~ "<a href=\""
            ~ AUTHOR_URL ~ "\">" ~ AUTHOR_NAME ~ "</a>" ~ " v" ~ VERSION ~ "-" ~ COMPILER));

    // Destroy the builder
    assert(builder !is null);
    builder.g_object_unref();
    builder = null;

    // Show the window
    assert(context !is null);
    assert(context.window !is null);
    (cast(GtkWidget*) context.window).gtk_widget_show_all();
}

//(app1,app2) => app1.desktopFileDateModifiedString > app2.desktopFileDateModifiedString
// import std.algorithm : sort, cmp;

// int[] array = [1, 2, 3, 4];

// auto array2 = sort(array);

// import std.algorithm.sorting : makeIndex;

// immutable(ApplicationInfo[]) arr = getApplications().idup;

// // auto index1 = new immutable(int)*[arr.length];
// // auto arri = makeIndex!("a > b")(arr,index1);
// auto appsSorted = arr[].sort!((a,b) => a < b);

//Tuple!(GtkTreeView*,"treeview",GAsyncQueue*,"queue")* t = new Tuple!(GtkTreeView*,"treeview",GAsyncQueue*,"queue")(context.treeview, context.queue);



import Config : DrillConfig;

struct DrillGtkContext
{
    import Context : DrillContext;

    // import std.path : dirName, buildNormalizedPath, absolutePath, buildPath;
    // import std.string : toStringz;
    // import Context : startCrawling, DrillContext;
    // import ApplicationInfo : ApplicationInfo, getApplications;

    GtkWindow* window;
    GAsyncQueue* queue;
    bool running = true;
    GtkTreeView* treeview;
    GtkListStore* liststore;
    shared(DList!FileInfo) buffer1;
    shared(DList!FileInfo) buffer2;
    shared(DList!FileInfo)* buffer;
    GtkEntry* search_input;
    DrillContext* context;
    GtkLabel* credits;
    GtkApplication* app;
    DrillConfig drillConfig;

    bool list_dirty = false;

    invariant
    {
        assert(app !is null);
    }
}


int main(string[] args)
{
    import std.path : buildPath, dirName;
    import Config : loadData;
    import std.file : thisExePath;

    import core.memory : GC;
    GC.disable();

    GtkApplication* app = gtk_application_new("me.santamorena.drill",
            GApplicationFlags.G_APPLICATION_FLAGS_NONE);
    assert(app !is null);

    DrillGtkContext drillGtkContext;
    drillGtkContext.app = app;

    assert(thisExePath !is null);
    assert(thisExePath.length > 0);
    drillGtkContext.drillConfig = loadData(buildPath(dirName(thisExePath), "Assets"));

    assert(app !is null);
    g_signal_connect(app, "activate", &activate, &drillGtkContext);
    int status = g_application_run(cast(GApplication*) app, 0, null);

    assert(app !is null);
    g_object_unref(app);

    return status;
}
