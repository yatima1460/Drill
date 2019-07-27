// import DrillGTK.Window : DrillWindow;

import std.concurrency;
import std.stdio : writeln;
import std.path : baseName, dirName, extension, buildNormalizedPath, absolutePath;

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

extern (C) @nogc nothrow struct GtkWindow;
extern (C) @trusted @nogc nothrow GtkWindow* GTK_WINDOW(GtkWidget*);
extern (C) @trusted @nogc nothrow GtkWindow* gtk_window_new(GtkWindowType);
extern (C) @trusted @nogc nothrow void gtk_window_set_gravity(GtkWindow*, GdkGravity);
extern (C) @trusted @nogc nothrow void gtk_window_set_title(GtkWindow*, const char*);
extern (C) @trusted @nogc nothrow void gtk_window_set_default_size(GtkWindow*, int, int);
extern (C) @trusted @nogc nothrow void gtk_window_set_default_geometry(
        GtkWindow* window, int width, int height);
extern (C) @trusted @nogc nothrow void gtk_window_set_resizable(GtkWindow*, bool);
extern (C) @trusted @nogc nothrow void gtk_window_set_decorated(GtkWindow*, bool);
extern (C) @trusted @nogc nothrow void gtk_window_fullscreen(GtkWindow*);
extern (C) @trusted @nogc nothrow void gtk_window_unfullscreen(GtkWindow*);
extern (C) @trusted @nogc nothrow void gtk_window_set_position(GtkWindow*, GtkWindowPosition);
extern (C) @trusted @nogc nothrow void gtk_window_move(GtkWindow* window, int x, int y);
extern (C) @trusted @nogc nothrow void gtk_window_set_keep_above(GtkWindow* w, bool);

extern (C) struct GtkBuilder;

extern (C) @trusted @nogc nothrow void window_destroy(GtkWindow* widget, void* arg)
in(widget != null)
in(arg == null)
{
    import core.stdc.stdio : printf;

    gtk_main_quit();
    //writeln("webview_destroy_cb");
    // bool* w = cast(bool*) arg;
    // *w = true;
    //writeln("destroy DONE");
}

extern (C) @nogc @trusted nothrow
{
    alias gpointer = void*;
    alias gint8 = byte;
    alias guint32 = uint;
    alias gint = int;
    alias guint = uint;
    alias gchar = char;
    alias guint16 = short;
    alias guint8 = ubyte;
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

extern (C) void gtk_search_changed(GtkEditable* widget, void* data)
{
    import std.stdio : writeln;

    char* str = gtk_editable_get_chars(widget, 0, -1);

    import std.string : fromStringz;

    writeln(data);
    writeln(fromStringz(str));
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

extern (C) bool check_escape(GtkWidget* widget, GdkEventKey* event, void* data)
{
    if (event.keyval == GDK_KEY_Escape)
    {
        gtk_main_quit();
        return true;
    }
    return false;
}

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

extern (C) struct GtkListStore;
extern (C) struct GtkTreeIter
{
    gint stamp;
    gpointer user_data;
    gpointer user_data2;
    gpointer user_data3;
};

extern (C) void gtk_list_store_append(GtkListStore* list_store, GtkTreeIter* iter);

extern (C) void gtk_list_store_set(GtkListStore* list_store, GtkTreeIter* iter, ...);

void appendApplication(GtkListStore* store, ApplicationInfo app)
{
    GtkTreeIter iter;

    /* Append a row and fill in some data */
    store.gtk_list_store_append(&iter);
    store.gtk_list_store_set(&iter, 0, null, 1, toStringz("bbb"), -1);

    // gtk_list_store_set (store, &iter, 4,toStringz("bbb"),-1);
    // gtk_list_store_set (store, &iter, 2,toStringz("aaa"),-1);
    // gtk_list_store_set (store, &iter, 3,toStringz("bbb"),-1);
}

extern (C) void gtk_widget_queue_draw(GtkWidget*);

extern(C) struct GtkTreeView;


extern (C) void gtk_tree_view_set_model(GtkTreeView*,GtkListStore*);
extern (C) void activate(GtkApplication* app, gpointer user_data)
in(app !is null)
in(user_data == null)
{
    GError* error = null;

    /* Initialize the .glade loader */
    GtkBuilder* builder = gtk_builder_new();
    assert(builder !is null);

    /* Load the UI from file */
    assert(builder !is null);
    assert(error is null);
    import std.file : thisExePath;

    assert(thisExePath !is null);
    if (builder.gtk_builder_add_from_file(toStringz(buildPath(dirName(thisExePath),
            "Assets/ui.glade")), &error) == 0)
    {
        assert(error !is null);
        g_printerr("Error loading file: %s\n", error.message);
        assert(error !is null);
        g_clear_error(&error);
        assert(false, "glade file not found");
    }

    /* Get the main window object from the .glade file */
    assert(builder !is null);
    GObject* window = builder.gtk_builder_get_object("window");
    assert(window !is null);

    /* Connect the GTK window to the application */
    assert(window !is null);
    assert(app !is null);
    (cast(GtkWindow*) window).gtk_window_set_application(app);

    /* Event when the window is closed using the [X]*/
    window.g_signal_connect("destroy", &window_destroy, null);

    /* Event when something is typed in the search box */
    auto search_input = builder.gtk_builder_get_object("search_input");
    assert(search_input !is null);
    search_input.g_signal_connect("changed", &gtk_search_changed, null);

    /* Event when a key is pressed:
        - Used to check Escape to close
        - Return to start the selected result 
    */
    assert(window !is null);
    assert(&check_escape !is null);
    window.g_signal_connect("key_press_event", &check_escape, null);

    /*
        Show a default list of apps
    */
    assert(builder !is null);
    auto liststore = builder.gtk_builder_get_object("liststore");
    assert(liststore !is null);
    foreach (application; getApplications())
    {
        assert(liststore !is null);
        (cast(GtkListStore*) liststore).appendApplication(application);
    }
    

    auto treeview = gtk_builder_get_object(builder,"treeview");
    (cast(GtkTreeView*)treeview).gtk_tree_view_set_model(cast(GtkListStore*)liststore);
    //gtk_widget_queue_draw(cast(GtkWidget*)treeview);

    /* Destroy the builder */
    assert(builder !is null);
    builder.g_object_unref();

    /* Show the window */
    assert(window !is null);
    (cast(GtkWidget*) window).gtk_widget_show_all();

    /* Start the main loop */
    gtk_main();
}

extern (C) void gtk_window_set_application(GtkWindow* self, GtkApplication* application);

int main(string[] args)
{
    int status;

    GtkApplication* app = gtk_application_new("me.santamorena.drill",
            GApplicationFlags.G_APPLICATION_FLAGS_NONE);
    g_signal_connect(app, "activate", &activate, null);
    status = g_application_run(cast(GApplication*) app, 0, null);
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
