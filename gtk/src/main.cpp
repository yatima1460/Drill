#include <gtk/gtk.h>

#include <assert.h>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <sstream>


void window_destroy(GtkWindow* window, gpointer data)
{
    assert(window != nullptr);
    // assert(data != nullptr);
    g_print("Window [X] pressed!\n");
}

static void activate(GtkApplication *app, gpointer user_data)
{
    g_print("Drill GTK\n");

    GError *error = nullptr;

    // Initialize the .glade loader
    GtkBuilder *builder = gtk_builder_new();
    assert(builder != nullptr);

    // Load the UI from file
    if (!std::filesystem::exists("assets/ui.glade"))
    {
        g_printerr("Error loading file ui.glade");
        exit(EXIT_FAILURE);
    }
    g_print("file ui.glade found!\n");
    assert(error == nullptr);
    std::string file_content;
    std::ifstream file("assets/ui.glade");
    std::stringstream buffer;
    buffer << file.rdbuf();
    file_content = buffer.str();

    if (gtk_builder_add_from_string(builder, file_content.c_str(), -1, &error) == 0)
    {
        assert(error != nullptr);
        g_printerr("Error loading file: %s\n", error->message);
        assert(error != nullptr);
        g_clear_error(&error);
        g_printerr("glade file not found");
        exit(EXIT_FAILURE);
    }
    g_print("file ui.glade loaded!\n");

    // Get the window from the .glade file
    GtkWindow *window = (GtkWindow *)gtk_builder_get_object(builder, "window");
    assert(window != nullptr);
    g_print("window found in glade file\n");

    // Load Drill icon
    if( gtk_window_set_icon_from_file(window,"assets/icon.png",&error) == 0)
    {
        assert(error != nullptr);
        g_printerr("Error loading file: %s\n", error->message);
        assert(error != nullptr);
        g_clear_error(&error);
        exit(EXIT_FAILURE);
    }

    // Set debug title if debug version
#ifndef NDEBUG
    assert(window != nullptr);
    gtk_window_set_title(window, "Drill (DEBUG VERSION)");
#endif

    // Connect the GTK window to the application
    assert(window != nullptr);
    assert(app != nullptr);
    gtk_window_set_application(window, app);


    // Event when the window is closed using the [X]
    g_signal_connect(window, "destroy", G_CALLBACK(window_destroy), nullptr);

    // Destroy the glade builder
    assert(builder != nullptr);
    g_object_unref(builder);
    builder = nullptr;
    g_print("glade builder destroyed\n");

    // Show the window
    assert(window != nullptr);
    gtk_widget_show_all((GtkWidget *)window);
    g_print("window shown\n");
}

int main(int argc, char **argv)
{
    GtkApplication *app = nullptr;
    int status = -1;

    app = gtk_application_new("software.drill", G_APPLICATION_FLAGS_NONE);
    assert(app != nullptr);

    g_signal_connect(app, "activate", G_CALLBACK(activate), NULL);
    status = g_application_run(G_APPLICATION(app), argc, argv);

    assert(app != nullptr);
    g_object_unref(app);
    return status;
}