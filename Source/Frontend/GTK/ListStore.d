

import ApplicationInfo : ApplicationInfo;
import std.string : toStringz;
import TreeIter : GtkTreeIter;
import Types;



    
extern(C) @trusted @nogc nothrow
{
    
    struct GtkListStore;
    void gtk_list_store_append(GtkListStore* list_store, GtkTreeIter* iter);
    void gtk_list_store_set(GtkListStore* list_store, GtkTreeIter* iter, ...);
    GtkListStore * gtk_list_store_new (gint n_columns, ...);

    void
gtk_list_store_clear (GtkListStore *list_store);
}

import FileInfo : FileInfo;


void appendApplication(GtkListStore* store, const(ApplicationInfo) app)
{
    GtkTreeIter iter;

    

    /* Append a row and fill in some data */
    store.gtk_list_store_append(&iter);
    store.gtk_list_store_set(&iter, 
        0, toStringz(app.icon),
        1, toStringz(app.name),
        2, toStringz(app.exec),
        //3, toStringz("0"),
        4, toStringz(app.desktopFileDateModifiedString), -1);

    // gtk_list_store_set (store, &iter, 4,toStringz("bbb"),-1);
    // gtk_list_store_set (store, &iter, 2,toStringz("aaa"),-1);
    // gtk_list_store_set (store, &iter, 3,toStringz("bbb"),-1);
}

void appendFileInfo(GtkListStore* store, FileInfo* fileInfo)
{
    GtkTreeIter iter;

    /* Append a row and fill in some data */
    store.gtk_list_store_append(&iter);
    store.gtk_list_store_set(&iter, 
        0, toStringz("none"),
        1, toStringz(fileInfo.fileName),
        2, toStringz(fileInfo.containingFolder),
        3, toStringz(fileInfo.sizeString),
        4, toStringz(fileInfo.dateModifiedString), -1);
}