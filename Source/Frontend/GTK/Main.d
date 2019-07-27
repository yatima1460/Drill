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

extern (C) @trusted @nogc nothrow void window_destroy(GtkWidget* widget, void* arg)
in(widget != null)
in(arg != null)
{
    //writeln("webview_destroy_cb");
    bool* w = cast(bool*) arg;
    *w = true;
    //writeln("destroy DONE");
}

alias guint = uint;
alias gchar = char;

extern (C) void gtk_init(int* argc, char*** argv);
extern (C) GtkBuilder* gtk_builder_new();


extern (C)
{
    guint gtk_builder_add_from_file(GtkBuilder* builder, const gchar* filename, GError** error);

    struct GError
    {
        uint domain;
        int code;
        char* message;
    };

    void g_printerr(const gchar* format, ...);
    void g_clear_error(GError** err);

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
}

int main(string[] args)
{
    GtkBuilder* builder;
    GObject* window;
    GObject* button;
    GError* error = null;


    // import core.runtime : CArgs;
    // Cargs c;

    int argc = 0;
    char[] argv = new char[0];

    gtk_init(&argc, null);

    /* Construct a GtkBuilder instance and load our UI description */
    builder = gtk_builder_new();
    if (gtk_builder_add_from_file(builder, "builder.ui", &error) == 0)
    {
        g_printerr("Error loading file: %s\n", error.message);
        g_clear_error(&error);
        return 1;
    }

    /* Connect signal handlers to the constructed widgets. */
    window = gtk_builder_get_object(builder, "window");
    g_signal_connect(window, "destroy", &gtk_main_quit, null);

    //   button = gtk_builder_get_object (builder, "button1");
    //   g_signal_connect (button, "clicked", G_CALLBACK (print_hello), null);

    //   button = gtk_builder_get_object (builder, "button2");
    //   g_signal_connect (button, "clicked", G_CALLBACK (print_hello), null);

    button = gtk_builder_get_object(builder, "quit");
    g_signal_connect(button, "clicked", &gtk_main_quit, null);

    gtk_main();

    return 0;
    // import core.stdc.stdio : printf;

    // if (gtk_init_check(null, null) == false)
    // {
    //     printf("can't initialize GTK\n");
    //     // throw new Exception("Can't initialize GTK");
    //     return 1;
    // }

    // auto window = gtk_window_new(GtkWindowType.GTK_WINDOW_TOPLEVEL);
    // assert(window !is null);

    // debug gtk_window_set_title(window, "Drill (DEBUG VERSION)");
    // else gtk_window_set_title(window, "Drill");
    // gtk_window_set_default_size(window, 940, 540);
    // gtk_window_set_resizable(window, true);
    // gtk_window_set_position(window, GtkWindowPosition.GTK_WIN_POS_CENTER);

    // gtk_widget_show_all(cast(GtkWidget*) window);

    // bool should_exit = false;

    // g_signal_connect_data(window, "destroy", &window_destroy, &should_exit,
    //         null, GConnectFlags.G_CONNECT_AFTER);

    // while (!should_exit)
    // {
    //     gtk_main_iteration_do(true);
    // }

    // return 0;

    // Application application = new Application("me.santamorena.drill", GApplicationFlags.FLAGS_NONE);
    // application.addOnActivate(delegate void(GioApplication app) {
    //     new DrillWindow(args[0], application);
    // });
    // return application.run(args);
}
