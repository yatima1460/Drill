
import Types;

extern(C) @trusted @nogc nothrow struct GtkTreeIter
{
    gint stamp;
    gpointer user_data;
    gpointer user_data2;
    gpointer user_data3;
};
