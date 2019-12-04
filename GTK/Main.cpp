
#include <gtk/gtk.h>

#include <assert.h>

   
int main(int argc, char const *argv[])
{



    GtkApplication* app = gtk_application_new("software.drill", G_APPLICATION_FLAGS_NONE);
    assert(app != nullptr);
   
    // DrillGtkContext drillGtkContext;
    // drillGtkContext.app = app;

    // import Config : loadMime;
    // drillGtkContext.mime = loadMime();

    // writeln(drillGtkContext.mime["mkv"]);

    
    // return 0;

    // assert(thisExePath !is null);
    // assert(thisExePath.length > 0);
    // drillGtkContext.drillConfig = loadData(dirName(thisExePath));
    // assert(app !is null);
    g_signal_connect(app, "activate", &activate, &drillGtkContext);
    int status = g_application_run((GApplication*) app, 0, null);


    

    // cleanGTK(app);

    return status;
}
