 
#include <gtk/gtk.h>
#include <assert.h>
#include <string>

#include "WindowContext.hpp"


void activate(GtkApplication* app, gpointer userObject)
{
    WindowContext* context = (WindowContext*) userObject;

    assert(context != nullptr);

    GError* error = nullptr;

    // Initialize the .glade loader
    GtkBuilder* builder = gtk_builder_new();
    assert(builder != nullptr);

    // Load the UI from file
    assert(builder != nullptr);
    assert(error == nullptr);


    // debug version loads the UI file from the .glade
    // release version actually compiles it inside the executable
    //
    // this is done because otherwise --force would be needed to update
    // the compiling of the .glade file and would just slow down the
    // debug version UI tests
// #ifndef NDEBUG
        const char* builderFile = "Assets/ui.glade";

        if (gtk_builder_add_from_file(builder, builderFile, &error) == 0)
        {
            assert(error  != nullptr);
            g_printerr("Error loading file: %s\n", error->message);
            assert(error != nullptr);
            g_clear_error(&error);
            assert(false); //"glade file not found"
        }
     
    
// #else
    
//         const(char[]) builderFile = import("Assets/ui.glade");
//         if (builder.gtk_builder_add_from_string(&builderFile[0], builderFile.length, &error) == 0)
//         {
//             assert(error != nullptr);
//             g_printerr("Error loading file: %s\n", error.message);
//             assert(error != nullptr);
//             g_clear_error(&error);
//             assert(false, "glade file not found");
//         }
// #endif

  // Get the main window object from the .glade file
    assert(context != nullptr);
    assert(builder != nullptr);
    assert(context->window == nullptr);
    context->window = (GtkWindow*) gtk_builder_get_object(builder, "window");
    assert(context->window != nullptr);

    // Set debug title if debug version
#ifndef NDEBUG
    assert(context != nullptr);
    assert(context->window != nullptr);
    gtk_window_set_title(context->window, "Drill (DEBUG VERSION)");
#endif


 // Connect the GTK window to the application
    assert(context != nullptr);
    assert(context->window != nullptr);
    assert(app != nullptr);
    gtk_window_set_application(context->window,app);




 // Destroy the builder
    assert(builder != nullptr);
    g_object_unref(builder);
    builder = nullptr;

    // Show the window
    assert(context != nullptr);
    assert(context->window != nullptr);
    gtk_widget_show_all(GTK_WIDGET(context->window));

}

 int main(int argc, char const *argv[])
 {
    GtkApplication* app = gtk_application_new("software.drill", GApplicationFlags::G_APPLICATION_FLAGS_NONE);
    assert(app != nullptr);

    WindowContext drillGtkContext = {0};
    drillGtkContext.app = app;
    //drillGtkContext.mime = loadMime();
    //drillGtkContext.drillConfig = loadData(buildPath(dirName(thisExePath), "Assets"));
  
    assert(app != nullptr);
    g_signal_connect(app, "activate", (GCallback)activate, &drillGtkContext);
    int status = g_application_run((GApplication*) app, 0, nullptr);

    assert(app != nullptr);
    g_object_unref(app);

    return status;
  
 }
 
 