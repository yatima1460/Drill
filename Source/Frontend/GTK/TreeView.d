


import ListStore : GtkListStore, gtk_list_store_new;
import Types;

extern(C) struct GtkTreeView;

extern (C) struct GtkTreeModel;
extern (C) void gtk_tree_view_set_model(GtkTreeView*,GtkTreeModel *);
GtkTreeModel * gtk_tree_view_get_model (GtkTreeView *tree_view);


GtkTreeModel* clean(GtkTreeView* treeview)
in (treeview !is null)
out(store; store !is null)
{
    
    immutable(int) G_TYPE_STRING = 15;
    GtkListStore* store = gtk_list_store_new(5,G_TYPE_STRING,G_TYPE_STRING,G_TYPE_STRING,G_TYPE_STRING,G_TYPE_STRING);
    assert(store !is null);

    assert(treeview !is null);
    assert(store !is null);
    treeview.gtk_tree_view_set_model(cast(GtkTreeModel*)store);
    assert(treeview !is null);
    assert(store !is null);

    return cast(GtkTreeModel*)store;
}