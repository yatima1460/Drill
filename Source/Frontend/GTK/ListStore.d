import ApplicationInfo : ApplicationInfo;
import std.string : toStringz;
import TreeIter : GtkTreeIter;
import Types;

//TODO: merge ApplicationInfo and FileInfo into one data type?

extern (C) @trusted @nogc pure nothrow
{

    struct GtkListStore;
    void gtk_list_store_append(GtkListStore* list_store, GtkTreeIter* iter);
    void gtk_list_store_set(GtkListStore* list_store, GtkTreeIter* iter, ...);
    GtkListStore* gtk_list_store_new(gint n_columns, ...);

    void gtk_list_store_clear(GtkListStore* list_store);
}

import FileInfo : FileInfo;

pure nothrow @trusted void appendApplication(GtkListStore* store, const(ApplicationInfo) app)
{
    GtkTreeIter iter;

    //iter.user_data3 = cast(void*)2;

    // HACK: to specify if a row is an app, an hidden space in the size field is added
    // tell me if you have a better idea, user_data in GtkTreeIter doesn't seem reliable

    /* Append a row and fill in some data */
    store.gtk_list_store_append(&iter);
    store.gtk_list_store_set(&iter,
        0, toStringz(app.icon),
        1, toStringz(app.name),
        2, toStringz(app.exec),
        3, toStringz(" "),
        4, toStringz(app.desktopFileDateModifiedString), 
        -1);
}

pure nothrow @trusted void appendFileInfo(GtkListStore* store, immutable(FileInfo) fileInfo)
in(store !is null)
{
    GtkTreeIter iter;

    //iter.user_data3 = cast(void*)1;

    import std.process : executeShell;
    import std.array : replace;

    string icon = "none";

    if (fileInfo.isDirectory)
    {
        icon = "folder";
    }
    // TODO: icons
    // else
    // {
    //     try
    //     {

    //         synchronized
    //         {
    //             immutable auto iconMaybe = executeShell("grep '" ~ fileInfo.extension.replace(".",
    //                     "") ~ "' /etc/mime.types");
    //             if (iconMaybe.status == 0)
    //             {

    //                 icon = iconMaybe.output.replace("/", "-");

    //             }
    //             else
    //             {
    //                 icon = "none";
    //             }
    //         }

    //     }
    //     catch (Exception e)
    //     {
    //         icon = "none";
    //     }

    // }

    auto name = toStringz(fileInfo.fileName);
    auto parent = toStringz(fileInfo.containingFolder);
    auto size = toStringz(fileInfo.sizeString);
    auto date = toStringz(fileInfo.dateModifiedString);

    /* Append a row and fill in some data */
    store.gtk_list_store_append(&iter);
    store.gtk_list_store_set(&iter, 0, toStringz(icon), 1, name, 2, parent, 3, size, 4, date, -1);

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
