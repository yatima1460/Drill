

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