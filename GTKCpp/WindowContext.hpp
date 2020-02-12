#pragma once

 
#include <gtk/gtk.h>

struct WindowContext
{
    // ApplicationInfo[] applications;
    GtkWindow* window;
    // GAsyncQueue* queue;
    // bool running = true;
    // GtkTreeView* treeview;
    // GtkListStore* liststore;
    // shared(DList!FileInfo) buffer1;
    // shared(DList!FileInfo) buffer2;
    // shared(DList!FileInfo)* buffer;
    // GtkEntry* search_input;
    // DrillContext context;
    // GtkLabel* credits;
    GtkApplication* app;
    // DrillConfig drillConfig;

    // string[string] mime;

    // long oldTime;

    // bool list_dirty = false;

  
};