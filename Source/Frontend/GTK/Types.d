
    
    extern(C) @trusted @nogc nothrow
    {
        
        alias gdouble = double;
        alias gpointer = void*;
        alias gboolean = bool;
        alias gint8 = byte;
        alias guint32 = uint;
        alias gint = int;
        alias guint = uint;
        alias gchar = char;
        alias guint16 = short;
        alias guint8 = ubyte;

        enum GtkDialogFlags
        {
            GTK_DIALOG_MODAL,
            GTK_DIALOG_DESTROY_WITH_PARENT,
            GTK_DIALOG_USE_HEADER_BAR
        }
    }
