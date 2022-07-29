#include <gtk/gtk.h>

#include <algorithm>
#include <assert.h>
#include <engine.h>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <sstream>
#include <unordered_map>
#include <vector>

#include "os.h"
#include "string_utils.hpp"

// TODO: icons on filenames
// TODO: right click menu and update screenshot with it
// TODO: pressing return should open the first result
// TODO: apps sorted by date
// TODO: code coverage
// TODO: modern round icon

std::unordered_map<std::string, std::string> icons_map;

struct icon_info
{
    char extension[PATH_MAX];
    char icon[PATH_MAX];
};

GtkApplication *app = nullptr;
std::vector<struct drill_crawler_config *> crawlers;
GAsyncQueue *queue = nullptr;
GtkListStore *liststore = nullptr;
GtkTreeView *treeview = nullptr;
long results_count = 0;
GtkLabel *credits = nullptr;
guint timeout = 0;

void load_icons_map()
{
    std::ifstream file("assets/icons.map");
    if (!file.is_open())
    {
        std::cerr << "Could not open icons.map" << std::endl;
        exit(1);
    }
    std::string line;
    while (std::getline(file, line))
    {
        //  Skip comments lines
        if (line.empty() || line[0] == '#')
            continue;

        auto tokens = Drill::string_utils::split(line, ' ');
        if (tokens.size() != 2)
        {
            std::cerr << "Invalid line in icons.map: " << line << std::endl;
            exit(1);
        }
        icons_map[tokens[0]] = tokens[1];
    }
    file.close();
   
    std::cout << "icons_map loaded: " << icons_map.size() << " icons found in mime.types file" << std::endl;
}

const char *get_gtk_icon(const char *extension)
{
    if (icons_map.count(extension))
    {
        return icons_map[extension].c_str();
    }
    std::cerr << "no icon found for extension: " << extension << std::endl;
    return "";
}

// Callback called when pressing [X]
void window_destroy(GtkWindow *window, gpointer data)
{
    assert(window != nullptr);
    // assert(data != nullptr);
    g_print("Window [X] pressed!\n");
}

// Callback called by GTK when ESC is pressed
bool check_escape(GtkWidget *widget, GdkEventKey *event, gpointer data)
{

    if (event->keyval == GDK_KEY_Escape)
    {
        g_print("ESC pressed\n");
        // assert(context !is null);
        // g_idle_remove_by_data(context);

        // assert(context != nullptr);
        //  FIXME: stop crawling
        drill_search_stop_sync(crawlers);

        // assert(app != nullptr);
        //g_application_quit(app);
        // FIXME: exit
        g_application_quit(G_APPLICATION(app));
        return true;
    }
    return false;
}



// Callback called by Drill when a new result is found
void result_found(struct drill_result result)
{

    /*
    README!!!

    DONT UPDATE THE UI FROM THIS FUNCTION BECAUSE IT'S CALLED FROM DRILL THREADS
    */

    auto heapResult = new struct drill_result(result);
    results_count++;

    // gtk_label_set_markup(credits, ("<span foreground='#00ff00'>Results: " + std::to_string(results_count) +
    // "</span>").c_str());
    if (queue != nullptr)
        g_async_queue_push(queue, heapResult);
    // gtk_queue = userObject;
    // g_async_queue_push(queue, result);
}

const char *get_filename_ext(const char *filename)
{
    const char *dot = strrchr(filename, '.');
    if (!dot || dot == filename)
        return "";
    return dot + 1;
}

void appendFileInfo(GtkListStore *store, struct drill_result *fileInfo, void *GTKIconsUnused)
{
    GtkTreeIter iter;

    std::string icon = "text-x-generic";

   

    if (fileInfo->is_directory)
    {
        icon = "folder";
    }
    else

    {

        icon = get_gtk_icon(get_filename_ext(fileInfo->path));
    }

   

    /* Append a row and fill in some data */
    gtk_list_store_append(store, &iter);

    auto time_str = Drill::string_utils::time_to_string(fileInfo->last_write_time);
    auto size_str = Drill::string_utils::size_to_string(fileInfo->file_size);

    gtk_list_store_set(store, &iter, 0, icon.c_str(), 1, basename(fileInfo->path), 2, fileInfo->path, 3,
                       size_str.c_str(), 4, time_str.c_str(), -1);
}

gboolean check_async_queue(gpointer user_data)
{
    if (queue == nullptr)
        return false;

    gpointer queue_data = nullptr;

    // If there is some data add it to the UI
    // Add a maximum of ~20 elements at a time to prevent GTK from lagging
    uint frameCutoff = 20;
    while (frameCutoff > 0 && (queue_data = g_async_queue_try_pop(queue)) != nullptr)
    {
        struct drill_result *fi = (struct drill_result *)queue_data;
        assert(fi != nullptr);
        assert(liststore != nullptr);

        appendFileInfo(liststore, fi, nullptr);

        delete fi;
        // gtk_entry_set_progress_pulse_step (context.search_input,0.001);
        // gtk_entry_progress_pulse (context.search_input);

        frameCutoff--;
    }

    if (credits != nullptr)
    {
        std::stringstream ss;
        ss << results_count << " results"
           << " version " << DRILL_VERSION;
        gtk_label_set_text(credits, ss.str().c_str());
    }

    return true;
}

void gtk_search_changed(GtkEditable *widget, gpointer data)
{
    g_print("search changed\n");

    // Stop updating the UI if there is a UI callback running
    if (timeout != 0)
        g_source_remove(timeout);

    // Add task on main thread to fetch results from Drill threads
    timeout = g_timeout_add(16, &check_async_queue, nullptr);

    // Stop crawling the Drill Core
    drill_search_stop_async(crawlers);
    drill_search_destroy_crawlers(crawlers);
    crawlers.clear();

    // Reset the results count
    results_count = 0;
    // Get input string in the search text field
    assert(widget != nullptr);
    char *str = gtk_editable_get_chars((GtkEditable *)widget, 0, -1);
    assert(str != nullptr);
    g_print("input string: '%s'\n", str);

    // Reset list
    gtk_list_store_clear(liststore);
    // liststore = gtk_list_store_new(5
    // ,G_TYPE_STRING,G_TYPE_STRING,G_TYPE_STRING,G_TYPE_STRING,G_TYPE_STRING); assert(liststore != nullptr);
    // gtk_tree_view_set_model(treeview, (GtkTreeModel*)liststore);

    // Reset queue
    g_async_queue_unref(queue);
    queue = g_async_queue_new();
    if (strlen(str) != 0)
    {
        crawlers = drill_search_async(str, result_found);
    }
}

void row_activated(GtkTreeView *tree_view, GtkTreePath *path, GtkTreeViewColumn *column, gpointer userObject)
{
    // info("Row double-click");

    char *cname;
    char *cpath;
    char *csize;

    GtkTreeIter iter;

    GtkTreeModel *model = gtk_tree_view_get_model(tree_view);

    if (gtk_tree_model_get_iter(model, &iter, path))
    {

        gtk_tree_model_get(model, &iter, 1, &cname, 2, &cpath, 3, &csize, -1);
    }
    else
    {
        assert(0);
    }

    drill_os_open(cpath);
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
    if (gtk_window_set_icon_from_file(window, "assets/icon.png", &error) == 0)
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

    /* Event when a key is pressed:
        - Used to check Escape to close
        - Return/Enter to start the selected result
    */
    g_signal_connect(window, "key_press_event", G_CALLBACK(check_escape), nullptr);

    // Load search entry from UI file
    GtkEntry *search_input = (GtkEntry *)gtk_builder_get_object(builder, "search_input");
    assert(search_input != nullptr);
    gtk_entry_set_progress_fraction(search_input, 0.0);
    gtk_entry_set_progress_pulse_step(search_input, 0.0);
    gtk_entry_progress_pulse(search_input);

    // Event when something is typed in the search box
    g_signal_connect(search_input, "changed", G_CALLBACK(gtk_search_changed), nullptr);

    // Load default empty list
    liststore = (GtkListStore *)gtk_builder_get_object(builder, "liststore");
    assert(liststore != nullptr);

    // Load default empty TreeView

    treeview = (GtkTreeView *)gtk_builder_get_object(builder, "treeview");
    // Event when double-click on a row
    g_signal_connect(treeview, "row-activated", G_CALLBACK(row_activated), nullptr);

    // Load bottom credits label
    credits = (GtkLabel *)gtk_builder_get_object(builder, "credits");
    assert(credits != nullptr);

    // Destroy the glade builder
    assert(builder != nullptr);
    g_object_unref(builder);
    builder = nullptr;
    g_print("glade builder destroyed\n");

    // Create async queue for Drill threads to put their results into
    queue = g_async_queue_new();
    assert(queue != nullptr);

    // Show the window
    assert(window != nullptr);
    gtk_widget_show_all((GtkWidget *)window);
    g_print("window shown\n");
}

int main(int argc, char **argv)
{

    load_icons_map();

    
    int status = -1;

    app = gtk_application_new("software.drill", G_APPLICATION_FLAGS_NONE);
    assert(app != nullptr);

    g_signal_connect(app, "activate", G_CALLBACK(activate), NULL);
    status = g_application_run(G_APPLICATION(app), argc, argv);

    assert(app != nullptr);
    g_object_unref(app);
    return status;
}