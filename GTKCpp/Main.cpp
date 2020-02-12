
#include <gtk/gtk.h>
#include <assert.h>
#include <string>

#include "WindowContext.hpp"
#include "Config.hpp"

#include "Booting.hpp"




void activate(GtkApplication *app, gpointer userObject)
{
    WindowContext *context = (WindowContext *)userObject;

    assert(context != nullptr);

    *context = loadUIFromDataFiles(*context);

  

    // Connect the GTK window to the application
    assert(context != nullptr);
    assert(context->window != nullptr);
    assert(app != nullptr);
    gtk_window_set_application(context->window, app);

    // Set debug title if debug version
#ifndef NDEBUG
    assert(context != nullptr);
    assert(context->window != nullptr);
    gtk_window_set_title(context->window, "Drill (DEBUG VERSION)");
#endif

    // Show the window
    assert(context != nullptr);
    assert(context->window != nullptr);
    gtk_widget_show_all(GTK_WIDGET(context->window));
}

int main(int argc, char const *argv[])
{
    GtkApplication *app = gtk_application_new(GTK_APP_NAME, GApplicationFlags::G_APPLICATION_FLAGS_NONE);
    assert(app != nullptr);

    WindowContext drillGtkContext = {0};
    drillGtkContext.app = app;
    //drillGtkContext.mime = loadMime();
    //drillGtkContext.drillConfig = loadData(buildPath(dirName(thisExePath), "Assets"));

    assert(app != nullptr);
    g_signal_connect(app, "activate", (GCallback)activate, &drillGtkContext);
    int status = g_application_run((GApplication *)app, 0, nullptr);

    assert(app != nullptr);
    g_object_unref(app);

    return status;
}
