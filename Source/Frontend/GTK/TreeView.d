


import ListStore : GtkListStore, gtk_list_store_new;
import Types;

extern(C) @trusted @nogc nothrow
{
    struct GtkTreeView;
    struct GtkTreeModel;
    void gtk_tree_view_set_model(GtkTreeView*,GtkTreeModel *);
    GtkTreeModel * gtk_tree_view_get_model (GtkTreeView *tree_view);
}




GtkTreeModel* clean(GtkTreeView* treeview)
in (treeview !is null)
out(store; store !is null)
{
    
    immutable(int) G_TYPE_STRING = 64;
    GtkListStore* store = gtk_list_store_new(5,G_TYPE_STRING,G_TYPE_STRING,G_TYPE_STRING,G_TYPE_STRING,G_TYPE_STRING);
    assert(store !is null);

    assert(treeview !is null);
    assert(store !is null);
    treeview.gtk_tree_view_set_model(cast(GtkTreeModel*)store);
    assert(treeview !is null);
    assert(store !is null);

    return cast(GtkTreeModel*)store;
}