

#include "Booting.hpp"
#include <assert.h>
#include "Config.hpp"
#include "Functional.hpp"

CONST WindowContext loadUIFromDataFiles(const WindowContext context)
{

    WindowContext newContext = context;

    GError *error = nullptr;

    // Initialize the .glade loader
    GtkBuilder *builder = gtk_builder_new();
    assert(builder != nullptr);

    // Load the UI from file
    assert(builder != nullptr);
    assert(error == nullptr);

    // loads the UI file from the .glade

    const char *builderFile = GTK_DATA_FILE;

    if (gtk_builder_add_from_file(builder, builderFile, &error) == 0)
    {
        assert(error != nullptr);
        g_printerr("Error loading file: %s\n", error->message);
        assert(error != nullptr);
        g_clear_error(&error);
        assert(false); //"glade file not found"
    }

    // Get the main window object from the .glade file
    assert(builder != nullptr);
    assert(newContext.window == nullptr);
    newContext.window = (GtkWindow *)gtk_builder_get_object(builder, "window");
    assert(newContext.window != nullptr);

    if(gtk_window_set_icon_from_file(newContext.window,GTK_ICON,&error) == 0)
    {
        assert(error != nullptr);
        g_printerr("Error loading file: %s\n", error->message);
        assert(error != nullptr);
        g_clear_error(&error);
        assert(false); // "error icon file"
    }



    // Destroy the builder
    assert(builder != nullptr);
    g_object_unref(builder);
    builder = nullptr;

    return newContext;
}


void bindEvent(const WindowContext* globalContext, GObject* object, const char* eventName, GCallback callback)
{
    assert(object != nullptr);
    assert(eventName != nullptr);
    assert(strlen(eventName) != 0);
    assert(callback != nullptr);
    gulong result = g_signal_connect(object, eventName, callback, (void*)globalContext);
    assert(result > 0);
}

// void bindClickXEvent(const WindowContext* globalContext, GCallback callback)
// {
//     // Event when the window is closed using the [X]
//     assert(context.window != nullptr);
//     assert(callback != nullptr);
//     g_signal_connect(G_OBJECT(newContext.window), "destroy", callback, globalContext);
// }


    // assert(context !is null);
    // assert(context.window !is null);
    // assert(&check_escape !is null);
    // assert(app !is null);
    // context.window.g_signal_connect("key_press_event", &check_escape, context);