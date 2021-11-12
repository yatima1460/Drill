
#include <gtk/gtk.h>
#include <assert.h>
#include <string>

#include "WindowContext.hpp"
#include "Config.hpp"
#include "Booting.hpp"


void window_destroy(GtkWindow* window, gpointer data)
{
    WindowContext* context = (WindowContext*) data;
    assert(context != nullptr);
   
    //context.context.threads.stopCrawlingAsync();

    //*context = DrillGtkContext();
}


bool check_keys(GtkWidget* widget, GdkEventKey* event, gpointer data)
{
    WindowContext* context = (WindowContext*) data;
    assert(context != nullptr);

    

    if (event->keyval == GDK_KEY_Escape)
    {
        //g_log("ESC pressed");


        assert(context != nullptr);
 
        //context.context.threads.stopCrawlingAsync();


        assert (context->app);
        g_application_quit(G_APPLICATION(context->app));

        return true;
    }
    return false;
}

void activate(GtkApplication *app, gpointer userObject)
{
    WindowContext *globalContext = (WindowContext *)userObject;

    assert(globalContext != nullptr);

    *globalContext = loadUIFromDataFiles(*globalContext);

    // Connect the GTK window to the application
    assert(globalContext != nullptr);
    assert(globalContext->window != nullptr);
    assert(app != nullptr);
    gtk_window_set_application(globalContext->window, app);

    // Set debug title if debug version
#ifndef NDEBUG
    assert(globalContext != nullptr);
    assert(globalContext->window != nullptr);
    gtk_window_set_title(globalContext->window, "Drill (DEBUG VERSION)");
#endif

    // Event when the window is closed using the [X]
    bindEvent(globalContext, G_OBJECT(globalContext->window), "destroy", G_CALLBACK(window_destroy));

    /* Event when a key is pressed:
        - Used to check Escape to close
        - Return/Enter to start the selected result 
    */
    bindEvent(globalContext, G_OBJECT(globalContext->window), "key_press_event", G_CALLBACK(check_keys));

    // Show the window
    assert(globalContext != nullptr);
    assert(globalContext->window != nullptr);
    gtk_widget_show_all(GTK_WIDGET(globalContext->window));
}

int main(int argc, char const *argv[])
{
    GtkApplication *app = gtk_application_new(GTK_APP_NAME, GApplicationFlags::G_APPLICATION_FLAGS_NONE);
    assert(app != nullptr);

    WindowContext globalContext = {0};
    globalContext.app = app;
    //drillGtkContext.mime = loadMime();
    //drillGtkContext.drillConfig = loadData(buildPath(dirName(thisExePath), "Assets"));

    assert(app != nullptr);
    g_signal_connect(app, "activate", (GCallback)activate, &globalContext);
    int status = g_application_run((GApplication *)app, 0, nullptr);

    assert(app != nullptr);
    g_object_unref(app);

    return status;
}
