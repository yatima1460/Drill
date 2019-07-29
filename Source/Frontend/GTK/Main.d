// import DrillGTK.Window : DrillWindow;

import std.concurrency;
import std.stdio : writeln;
import std.path : baseName, dirName, extension, buildNormalizedPath, absolutePath;

import ListStore : GtkListStore, appendApplication;

import Types;

import TreeIter : GtkTreeIter;

import TreeView : GtkTreeView;

import std.typecons : tuple, Tuple;

extern (C) struct GtkEntry;

// import gtk.Application : Application;
// import gio.Application : GioApplication = Application;
// import gtk.Application : GApplicationFlags;

/+
    GTK
+/
extern (C) @trusted @nogc nothrow int gtk_init_check(int* argc, char*** argv);
extern (C) @trusted @nogc nothrow int gtk_main_iteration_do(int);
extern (C) @trusted @nogc nothrow void* G_CALLBACK(void*);

/+
    GDK
+/
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
extern (C) @trusted @nogc nothrow int gdk_screen_width();
extern (C) @trusted @nogc nothrow int gdk_screen_height();

/+
    G
+/
enum GConnectFlags
{
    G_CONNECT_AFTER,
    G_CONNECT_SWAPPED
};
extern (C) @nogc nothrow struct GObject;
extern (C) @trusted @nogc nothrow void g_signal_connect_data(void* instance, const char* detailed_signal,
        void* c_handler, void* data, void* destroy_data, GConnectFlags connect_flags);

/+
    GTKWidget
+/
extern (C) @nogc nothrow struct GtkWidget;
extern (C) @trusted @nogc nothrow GObject* G_OBJECT(GtkWidget*);
extern (C) @trusted @nogc nothrow void gtk_widget_set_size_request(GtkWidget*, int, int);
extern (C) @trusted @nogc nothrow void gtk_widget_show_all(GtkWidget*);

/*
    GTKWindow
*/
extern (C) @nogc nothrow enum GtkWindowType
{
    GTK_WINDOW_TOPLEVEL,
    GTK_WINDOW_POPUP
};
extern (C) @nogc nothrow enum GtkWindowPosition
{
    GTK_WIN_POS_NONE,
    GTK_WIN_POS_CENTER,
    GTK_WIN_POS_MOUSE,
    GTK_WIN_POS_CENTER_ALWAYS,
    GTK_WIN_POS_CENTER_ON_PARENT
}

extern (C) @trusted @nogc nothrow
{
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

    // (void* instance, const char* detailed_signal, void* c_handler, void* data, void* destroy_data, GConnectFlags connect_flags);

    // (window, "destroy", G_CALLBACK (gtk_main_quit), NULL);
    void g_signal_connect(void* instance, const char* detailed_signal, void* c_handler, void* data)
    {
        g_signal_connect_data(instance, detailed_signal, c_handler, data, null,
                GConnectFlags.G_CONNECT_AFTER);
    }

    void gtk_main();
    void gtk_main_quit();

    GtkApplication* gtk_application_new(const gchar* application_id, GApplicationFlags flags);

    int g_application_run(GApplication* application, int argc, char** argv);

    struct GApplication;

    void g_object_unref(gpointer object);
}

extern(C) void window_destroy(GtkWindow* window, gpointer data)
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

  extern(C) bool check_escape(GtkWidget* widget, GdkEventKey* event, gpointer data)
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

extern (C) struct GdkEventKey
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

import std.path : dirName, buildNormalizedPath, absolutePath, buildPath;

import std.string : toStringz;

import Context : startCrawling, DrillContext;
import ApplicationInfo : ApplicationInfo, getApplications;

extern (C) guint gtk_builder_add_from_string(GtkBuilder* builder,
        const gchar* buffer, ulong length, GError** error);

extern (C) struct GtkApplication;
extern (C) enum GApplicationFlags
{
    G_APPLICATION_FLAGS_NONE
}

extern (C) void gtk_widget_queue_draw(GtkWidget*);

extern (C) @nogc struct GtkLabel;
extern (C) @nogc void gtk_label_set_markup(GtkLabel* label, const gchar* str);
extern (C) @nogc void g_async_queue_push(GAsyncQueue* queue, gpointer data);

import FileInfo : FileInfo;

void resultFound(immutable(FileInfo) result, void* userObject)
in (userObject !is null)
{
    DrillGtkContext* tuple = cast(DrillGtkContext*)userObject;
    assert(tuple !is null);
    assert(tuple.queue !is null);
    import core.memory;

    // FileInfo* memory = new FileInfo();
    // //FileInfo* memory = cast(FileInfo*)GC.malloc(result.sizeof);

    // *memory = *result;
    import ListStore : appendFileInfo;

   
  
    synchronized
    {
    auto bufferNotShared = cast(DList!FileInfo*)tuple.buffer;
     (*bufferNotShared).insertFront(result);
    tuple.list_dirty = true;

    }


        // appendFileInfo(tuple.liststore,result);
    
  
    
    
    //g_async_queue_push(tuple.queue, result);
}

extern(C) struct GtkTreePath;
extern(C) struct GtkTreeViewColumn;

extern(C) struct GtkTreeModel;

extern(C) GtkTreeModel* gtk_tree_view_get_model(GtkTreeView*);

extern(C) gboolean gtk_tree_model_get_iter(GtkTreeModel*,GtkTreeIter*,GtkTreePath*);

extern(C) void gtk_tree_model_get(GtkTreeModel *, GtkTreeIter*,...);


// extern (C) gtk_list_store_get_iter()

extern(C) void row_activated(GtkTreeView *tree_view, GtkTreePath *path, GtkTreeViewColumn *column, gpointer userObject)
in(tree_view !is null)
in(path !is null)
in(column !is null)
in (userObject !is null)
{
   


 DrillGtkContext* context = cast(DrillGtkContext*) userObject;
    assert(context !is null);

    GtkTreeIter iter;
    //    gtk_list_store_get_iter(ti, tp);

        GtkTreeModel *model = gtk_tree_view_get_model(tree_view);

    char* cname;
    char* cpath;

   if (gtk_tree_model_get_iter(model, &iter, path)) 
   {
      gtk_tree_model_get (model, &iter, 1, &cname, 2, &cpath, -1);
      // Here the variables int_data and str_data should be filled with
      // relevant data
   }

        // immutable(string) path = this.liststore.getValueString(ti, Column.PATH);
        // immutable(string) name = this.liststore.getValueString(ti, Column.NAME);
        // immutable(string) type = this.liststore.getValueString(ti, Column.TYPE);
        import std.string : fromStringz;
      import std.path : chainPath;
      import std.array : array, split;
      import std.conv : to ;
      import core.stdc.stdio;
       // immutable(string) nameCell = to!string(fromStringz(cname));

       // string[] splitted = split(nameCell,"/");

        //immutable(string) name = splitted[0];

         import Utils : openFile;

       string chained = to!string(chainPath(fromStringz(cpath), fromStringz(cname)).array);
        try
        {
           
            openFile(chained);
        }
        catch (Exception e)
        {

              import std.process : spawnProcess;
                import std.process : Config;
                import Utils : cleanExecLine;
              spawnProcess(cleanExecLine(to!string(fromStringz(cpath))), null, Config.none, null);
           //  openFile(fromStringz());


            // MessageDialog d = new MessageDialog(context.window, GtkDialogFlags.MODAL, MessageType.ERROR,
            //         ButtonsType.OK, "Error opening file `" ~ chained ~ "`\n" ~ e.msg);
            // d.run();
            // d.destroy();
             printf("error\n");
        }

import core.stdc.stdio;
    printf("row_activated\n");
}

extern(C) void gtk_search_changed(in GtkEditable* widget, void* userObject)
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
        stopCrawlingAsync(*context.context);
        //context.context.destroy();
        context.context = null;
    }

    //context.list_dirty = true;

    //context.list_dirty = true;

    context.buffer1 = DList!FileInfo();
    context.buffer2 = DList!FileInfo();
    context.buffer = &context.buffer1;

    // Get input string in the search text field
    char* str = gtk_editable_get_chars(cast(GtkEditable*)widget, 0, -1);
    assert(str !is null);

    // Log
    //printf("Search changed: %s\n", str);



    // Clean the list
    assert(context !is null);
    assert(context.liststore !is null);
    //context.liststore.gtk_list_store_clear();

    assert(context.treeview !is null);

    const(GtkTreeModel*) newStore = context.treeview.clean();
    assert(newStore !is null);
    //g_object_unref(context.liststore);
    context.liststore = cast(GtkListStore*) newStore;
    assert(context.liststore !is null);

    const(string) searchString = to!string(str);


    //TODO: delete the old one
    context.queue = g_async_queue_new();


    if (searchString.length > 0)
    {
        // Start new crawling
        assert(context !is null);
        assert(context.context is null);
        //printf("gtk_search_changed context:%p\n",context);
        context.context = startCrawling(context.drillConfig, searchString, &resultFound, context);
        assert(context.context !is null);
    }
}

import std.container.dlist : DList;

extern (C) gboolean check_async_queue(gpointer user_data)
in(user_data !is null)
{

try
    {
    DrillGtkContext* context = cast(DrillGtkContext*) user_data;
    assert(context !is null);


    import ListStore : appendFileInfo;


    if (context.list_dirty)
    {
        assert(context.buffer != null);
        assert(context.buffer == &context.buffer1
                || context.buffer == &context.buffer2);
        if (context.buffer == &context.buffer1)
            context.buffer = &context.buffer2;
        if (context.buffer == &context.buffer2)
            context.buffer = &context.buffer1;
        //context.buffer_mutex.lock_nothrow();
        DList!FileInfo thread_local_buffer = cast(DList!FileInfo)*context.buffer;
        foreach (FileInfo fi; thread_local_buffer)
            context.liststore.appendFileInfo(fi);
        // thread_local_buffer.clear();
        *context.buffer = DList!FileInfo();




        context.list_dirty = false;
    }

      if (!context.running)
        {
            return 0;
        }

 }
    catch (Throwable t)
    {

        return 0;
    }
    return 1;
//     import ListStore : appendFileInfo;

//     
//     

//     // Get the next FileInfo in queue
//     assert(context !is null);
//     assert(context.queue !is null);
//     const(gpointer) queue_data = context.queue.g_async_queue_try_pop();

//     // If there is some data to add to the UI
//     if (queue_data !is null)
//     {
//         FileInfo* fi = cast(FileInfo*) queue_data;
//         assert(fi !is null);

//         assert(context !is null);
//         assert(context.liststore !is null);
//         assert(fi !is null);
//         appendFileInfo(context.liststore,fi);
//     }

//     // If this function returns false GTK will stop queueing it
//     return context.running;
}

extern (C) @nogc @trusted nothrow
{
    alias GSourceFunc = void*;

    struct GAsyncQueue;
    guint g_idle_add(GSourceFunc func, gpointer data);
    gpointer g_async_queue_try_pop(GAsyncQueue* queue);
    GAsyncQueue* g_async_queue_new();
}

struct DrillGtkBuffer
{

    GAsyncQueue* queue;
    invariant
    {
        assert(queue !is null);
    }

    GtkListStore* store;
    invariant
    {
        assert(store !is null);
    }
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

    
    

    DrillGtkContext* context = cast(DrillGtkContext*) userObject;
    assert(context !is null);

    assert(context !is null);
    assert(app !is null);
    context.app = app;

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
        - Return to start the selected result 
    */
    printf("activate context:%p\n",context);
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
    g_idle_add(&check_async_queue, context);

    // Load default empty TreeView
    assert(context !is null);
    assert(context.treeview is null);
    context.treeview = cast(GtkTreeView*) gtk_builder_get_object(builder, "treeview");
    assert(context.treeview !is null);


    context.treeview.g_signal_connect("row-activated", &row_activated, context);

    // Set empty ListStore to the TreeView
    assert(context !is null);
    assert(context.treeview !is null);
    assert(context.liststore !is null);
    context.treeview.gtk_tree_view_set_model(cast(GtkTreeModel*) context.liststore);

    // Load search entry from UI file
    assert(context !is null);
    assert(context.search_input is null);
    assert(builder !is null);
    context.search_input = cast(GtkEntry*)builder.gtk_builder_get_object("search_input");
    assert(context.search_input !is null);

    // Event when something is typed in the search box
    
    assert(context !is null);
    assert(&gtk_search_changed !is null);
    assert(context.search_input !is null);
    context.search_input.g_signal_connect("changed", &gtk_search_changed, context);

    // Load bottom credits label
    assert(context !is null);
    assert(context.credits is null);
    context.credits = cast(GtkLabel*)gtk_builder_get_object(builder, "credits");
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
            immutable(string) COMPILER_META = " "~name~" Compiler Vendor: "~to!string(vendor) ~ 
                                      " Compiler version: v" ~ to!string(version_major) ~ "." ~ to!string(version_minor) ~ 
                                      " D version:" ~ to!string(D_major);
    }
    else
    {
            immutable(string) COMPILER_META = "";
    }

    version (LDC)
        immutable(string) COMPILER = "LLVM " ~ COMPILER_META;
    version (DigitalMars)
        immutable(string) COMPILER = "DMD" ~ COMPILER_META;
    version (GNU)
        immutable(string) COMPILER = "GNU" ~ COMPILER_META;
    version (SDC)
        immutable(string) COMPILER = "SDC" ~ COMPILER_META;

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
    



extern (C) void gtk_window_set_application(GtkWindow* self, GtkApplication* application);

import Config : DrillConfig;

struct DrillGtkContext
{
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


extern(C) @nogc @trusted nothrow void gtk_widget_destroy(GtkWidget*);

int main(string[] args)
{
    import core.memory;
    //GC.disable();
    
    

    

    GtkApplication* app = gtk_application_new("me.santamorena.drill", GApplicationFlags.G_APPLICATION_FLAGS_NONE);
    assert(app !is null);
    //GC.addRoot(app);

    DrillGtkContext drillGtkContext;
    import Config : loadData;

    // Load config files
    // assert(thisExePath !is null);
    // auto assetsPath = toStringz();
    // assert(assetsPath !is null);
    
    import std.file : thisExePath;
    drillGtkContext.drillConfig = loadData(buildPath(dirName(thisExePath), "Assets"));
    //GC.addRoot(&app);
    
    g_signal_connect(app, "activate", &activate, &drillGtkContext);
    int status = g_application_run(cast(GApplication*) app, 0, null);

    // g_object_unref(drillGtkContext.buffer1);
    // g_object_unref(drillGtkContext.buffer2);
    // assert(drillGtkContext.liststore !is null);
    // g_object_unref(drillGtkContext.liststore);
    // assert(drillGtkContext.queue !is null);
    // g_object_unref(drillGtkContext.queue);
    // assert(drillGtkContext.search_input !is null);
    // g_object_unref(drillGtkContext.search_input);
    // assert(drillGtkContext.treeview !is null);
    // g_object_unref(drillGtkContext.treeview);
    //  assert(drillGtkContext.window !is null);
    //g_object_unref(drillGtkContext.window);
    // (cast(GtkWidget*)drillGtkContext.window).gtk_widget_destroy();

    assert(app !is null);
    g_object_unref(app);

    return status;
}
//     assert(args[0] !is null);

//     ApplicationInfo[] ai = getApplications();
//     // TODO: import core.runtime : CArgs;

//     auto assetsFolder = buildPath(absolutePath(dirName(buildNormalizedPath(args[0]))), "Assets");

//     /* Initialize GTK */
//     gtk_init(null, null);

//     GtkApplication* app = gtk_application_new("me.santamorena.drill");

//     /* Event when window is closed using the [X]*/
//     g_signal_connect(window, "destroy", &window_destroy, null);

//     

//     /* Event when a key is pressed 
//         Used to check Escape to close and Return to start the selected result
//     */
//     g_signal_connect(window, "key_press_event", &check_escape, null);

//     //gtk_widget_show_all(cast(GtkWidget*)window);

//     // Start the GTK loop
//     writeln("GTK loop started");
//     gtk_main();
//     writeln("GTK loop ended");

//     return 0;
// }
