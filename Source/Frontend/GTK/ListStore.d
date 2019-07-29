import ApplicationInfo : ApplicationInfo;
import std.string : toStringz;
import TreeIter : GtkTreeIter;
import Types;

extern (C) @trusted @nogc nothrow
{

    struct GtkListStore;
    void gtk_list_store_append(GtkListStore* list_store, GtkTreeIter* iter);
    void gtk_list_store_set(GtkListStore* list_store, GtkTreeIter* iter, ...);
    GtkListStore* gtk_list_store_new(gint n_columns, ...);

    void gtk_list_store_clear(GtkListStore* list_store);
}

import FileInfo : FileInfo;

void appendApplication(GtkListStore* store, const(ApplicationInfo) app)
{
    GtkTreeIter iter;

    /* Append a row and fill in some data */
    store.gtk_list_store_append(&iter);
    store.gtk_list_store_set(&iter, 0, toStringz(app.icon), 1, toStringz(app.name), 2, toStringz(app.exec), 4, toStringz(app.desktopFileDateModifiedString), -1);
}

@trusted nothrow void appendFileInfo(GtkListStore* store, immutable(FileInfo) fileInfo)
in(store !is null)
{
    GtkTreeIter iter;

    auto icon = toStringz("none");
    auto name = toStringz(fileInfo.fileName);
    auto parent = toStringz(fileInfo.containingFolder);
    auto size = toStringz(fileInfo.sizeString);
    auto date = toStringz(fileInfo.dateModifiedString);

    /* Append a row and fill in some data */
    store.gtk_list_store_append(&iter);
    store.gtk_list_store_set(&iter, 0, icon, 1, name, 2, parent, 3, size, 4, date, -1);

}

// @trusted nothrow void  appendListData(GtkListStore* store, immutable(ListData) listData)
// {
//     GtkTreeIter iter;

//     auto icon = toStringz("none");
//     auto name = toStringz(listData.name);
//     auto parent = toStringz(listData.path);
//     auto size = toStringz(listData.size);
//     auto date = toStringz(listData.date);

//     /* Append a row and fill in some data */
//     store.gtk_list_store_append(&iter);
//     store.gtk_list_store_set(&iter, 0, icon, 1, name, 2, parent, 3, size, 4, date, -1);
// }