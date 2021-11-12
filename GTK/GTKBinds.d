/*
    All GTK binds needed to show the UI
*/
extern (C) pure nothrow @trusted @nogc
{

    struct GdkDevice;

    // It's actually a Union of all Event types
    alias GdkEvent = void;

    struct GtkMenu;
    struct GtkMenuItem;
    struct GtkMenuShell;
    struct GtkTreeSelection;

    GtkTreeSelection* gtk_tree_view_get_selection(GtkTreeView*);

    gboolean gtk_tree_selection_get_selected(GtkTreeSelection*, GtkTreeModel**, GtkTreeIter*);

    void gtk_widget_show(GtkWidget*);

    void gtk_menu_shell_append(GtkMenuShell* menu_shell, GtkWidget* child);

    GtkWidget* gtk_menu_new();
    GtkWidget* gtk_menu_item_new();
    GtkWidget* gtk_menu_item_new_with_label(const gchar* name);

    GtkLabel* gtk_label_new(const gchar* name);

    //   void gtk_menu_add(GtkMenuItem * menu_item);
    // void gtk_menu_show_all();

    void gtk_menu_attach(GtkMenu* menu, GtkMenuItem* child, guint left_attach,
            guint right_attach, guint top_attach, guint bottom_attach);

    gboolean gtk_window_set_icon_from_file(GtkWindow* window, const gchar* filename, GError** err);

    guint gtk_builder_add_from_string(GtkBuilder* builder, const gchar* buffer,
            gsize length, GError** error);
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
    alias gsize = ulong;

    void gtk_widget_destroy(GtkWidget*);
    void gtk_window_set_application(GtkWindow* self, GtkApplication* application);
    alias GSourceFunc = void*;
    struct GAsyncQueue;
    guint g_idle_add(GSourceFunc func, gpointer data);
    guint g_timeout_add(guint interval, GSourceFunc func, gpointer data);

    gpointer g_async_queue_try_pop(GAsyncQueue* queue);
    GAsyncQueue* g_async_queue_new();

    struct GdkEventKey
    {
        GdkEventType type;
        GdkWindow* window;
        gint8 send_event;
        guint32 time;
        guint state;
        guint keyval;
        gint length;
        gchar* string;
        guint16 hardware_keycode;
        guint8 group;
        bool is_modifier;
    };

    struct GdkEventButton
    {
        GdkEventType type;
        GdkWindow* window;
        gint8 send_event;
        guint32 time;
        gdouble x;
        gdouble y;
        gdouble* axes;
        guint state;
        guint button;
        GdkDevice* device;
        gdouble x_root, y_root;
    };

    struct GtkApplication;
    enum GApplicationFlags
    {
        G_APPLICATION_FLAGS_NONE
    }

    struct GtkLabel;
    void gtk_label_set_markup(GtkLabel* label, const gchar* str);
    void g_async_queue_push(GAsyncQueue* queue, gpointer data);
    void gtk_widget_queue_draw(GtkWidget*);
    struct GtkTreePath;
    struct GtkTreeViewColumn;
    struct GtkTreeModel;

    gboolean gtk_tree_model_get_iter(GtkTreeModel*, GtkTreeIter*, GtkTreePath*);
    void gtk_tree_model_get(GtkTreeModel*, GtkTreeIter*, ...);

    enum GtkDialogFlags
    {
        GTK_DIALOG_MODAL,
        GTK_DIALOG_DESTROY_WITH_PARENT,
        GTK_DIALOG_USE_HEADER_BAR
    }

    gint gtk_tree_model_iter_n_children(GtkTreeModel* tree_model, GtkTreeIter* iter);
    gboolean g_idle_remove_by_data(gpointer data);
    const(gchar*) g_strerror();
    struct GtkDialog;
    enum GtkButtonsType
    {
        GTK_BUTTONS_NONE,
        GTK_BUTTONS_OK,
        GTK_BUTTONS_CLOSE,
        GTK_BUTTONS_CANCEL,
        GTK_BUTTONS_YES_NO,
        GTK_BUTTONS_OK_CANCEL
    }

    enum GtkMessageType
    {
        GTK_MESSAGE_INFO,
        GTK_MESSAGE_WARNING,
        GTK_MESSAGE_QUESTION,
        GTK_MESSAGE_ERROR,
        GTK_MESSAGE_OTHER
    }

    GtkWidget* gtk_message_dialog_new(GtkWindow* parent, GtkDialogFlags flags,
            GtkMessageType type, GtkButtonsType buttons, const gchar* message_format, ...);
    gint gtk_dialog_run(GtkDialog* dialog);

    void gtk_entry_set_progress_fraction(GtkEntry* entry, gdouble fraction);
    void gtk_entry_set_progress_pulse_step(GtkEntry* entry, gdouble fraction);
    void gtk_entry_progress_pulse(GtkEntry* entry);

    void g_async_queue_unref(GAsyncQueue*);

    struct GtkEntry;

    int gtk_init_check(int* argc, char*** argv);
    int gtk_main_iteration_do(int);
    void* G_CALLBACK(void*);

    enum GdkGravity
    {
        GDK_GRAVITY_NORTH_WEST,
        GDK_GRAVITY_NORTH,
        GDK_GRAVITY_NORTH_EAST,
        GDK_GRAVITY_WEST,
        GDK_GRAVITY_CENTER,
        GDK_GRAVITY_EAST,
        GDK_GRAVITY_SOUTH_WEST,
        GDK_GRAVITY_SOUTH,
        GDK_GRAVITY_SOUTH_EAST,
        GDK_GRAVITY_STATIC
    };

    struct GObject;
    enum GConnectFlags
    {
        G_CONNECT_AFTER,
        G_CONNECT_SWAPPED
    };
    void g_signal_connect_data(void* instance, const char* detailed_signal,
            void* c_handler, void* data, void* destroy_data, GConnectFlags connect_flags);

    int gdk_screen_width();
    int gdk_screen_height();

    struct GtkWidget;
    GObject* G_OBJECT(GtkWidget*);
    void gtk_widget_set_size_request(GtkWidget*, int, int);
    void gtk_widget_show_all(GtkWidget*);

    enum GtkWindowType
    {
        GTK_WINDOW_TOPLEVEL,
        GTK_WINDOW_POPUP
    };

    enum GtkWindowPosition
    {
        GTK_WIN_POS_NONE,
        GTK_WIN_POS_CENTER,
        GTK_WIN_POS_MOUSE,
        GTK_WIN_POS_CENTER_ALWAYS,
        GTK_WIN_POS_CENTER_ON_PARENT
    }

    struct GtkWindow;
    struct GtkBuilder;

    void g_application_quit(GtkApplication*);

    GtkWindow* GTK_WINDOW(GtkWidget*);
    GtkWindow* gtk_window_new(GtkWindowType);
    void gtk_window_set_gravity(GtkWindow*, GdkGravity);
    void gtk_window_set_title(GtkWindow*, const char*);
    void gtk_window_set_default_size(GtkWindow*, int, int);
    void gtk_window_set_default_geometry(GtkWindow* window, int width, int height);
    void gtk_window_set_resizable(GtkWindow*, bool);
    void gtk_window_set_decorated(GtkWindow*, bool);
    void gtk_window_fullscreen(GtkWindow*);
    void gtk_window_unfullscreen(GtkWindow*);
    void gtk_window_set_position(GtkWindow*, GtkWindowPosition);
    void gtk_window_move(GtkWindow* window, int x, int y);
    void gtk_window_set_keep_above(GtkWindow* w, bool);

    immutable(int) GDK_KEY_Escape = 0xff1b;

    void gtk_menu_popup_at_pointer(GtkMenu* menu, const GdkEvent* trigger_event);

    enum GdkEventType
    {
        GDK_NOTHING = -1,
        GDK_DELETE = 0,
        GDK_DESTROY = 1,
        GDK_EXPOSE = 2,
        GDK_MOTION_NOTIFY = 3,
        GDK_BUTTON_PRESS = 4,
        GDK_2BUTTON_PRESS = 5,
        GDK_DOUBLE_BUTTON_PRESS = GDK_2BUTTON_PRESS,
        GDK_3BUTTON_PRESS = 6,
        GDK_TRIPLE_BUTTON_PRESS = GDK_3BUTTON_PRESS,
        GDK_BUTTON_RELEASE = 7,
        GDK_KEY_PRESS = 8,
        GDK_KEY_RELEASE = 9,
        GDK_ENTER_NOTIFY = 10,
        GDK_LEAVE_NOTIFY = 11,
        GDK_FOCUS_CHANGE = 12,
        GDK_CONFIGURE = 13,
        GDK_MAP = 14,
        GDK_UNMAP = 15,
        GDK_PROPERTY_NOTIFY = 16,
        GDK_SELECTION_CLEAR = 17,
        GDK_SELECTION_REQUEST = 18,
        GDK_SELECTION_NOTIFY = 19,
        GDK_PROXIMITY_IN = 20,
        GDK_PROXIMITY_OUT = 21,
        GDK_DRAG_ENTER = 22,
        GDK_DRAG_LEAVE = 23,
        GDK_DRAG_MOTION = 24,
        GDK_DRAG_STATUS = 25,
        GDK_DROP_START = 26,
        GDK_DROP_FINISHED = 27,
        GDK_CLIENT_EVENT = 28,
        GDK_VISIBILITY_NOTIFY = 29,
        GDK_SCROLL = 31,
        GDK_WINDOW_STATE = 32,
        GDK_SETTING = 33,
        GDK_OWNER_CHANGE = 34,
        GDK_GRAB_BROKEN = 35,
        GDK_DAMAGE = 36,
        GDK_TOUCH_BEGIN = 37,
        GDK_TOUCH_UPDATE = 38,
        GDK_TOUCH_END = 39,
        GDK_TOUCH_CANCEL = 40,
        GDK_TOUCHPAD_SWIPE = 41,
        GDK_TOUCHPAD_PINCH = 42,
        GDK_EVENT_LAST /* helper variable for decls */
    }

    struct GdkWindow;
    void gtk_init(int* argc, char*** argv);
    GtkBuilder* gtk_builder_new();

    guint gtk_builder_add_from_file(GtkBuilder* builder, const gchar* filename, GError** error);

    struct GError
    {
        uint domain;
        int code;
        char* message;
    };

    void g_printerr(const gchar* format, ...);
    void g_clear_error(GError** err);

    struct GtkEditable;
    gchar* gtk_editable_get_chars(GtkEditable* editable, gint start_pos, gint end_pos);

    GObject* gtk_builder_get_object(GtkBuilder* builder, const gchar* name);

    void g_signal_connect(void* instance, const char* detailed_signal, void* c_handler, void* data)
    {
        g_signal_connect_data(instance, detailed_signal, c_handler, data, null,
                GConnectFlags.G_CONNECT_AFTER);
    }

    void gtk_main();
    void gtk_main_quit();

    GtkApplication* gtk_application_new(const gchar* application_id, GApplicationFlags flags);

    int g_application_run(GApplication* application, int argc, char** argv);

    struct GApplication;

    void g_object_unref(gpointer object);

    struct GtkTreeIter
    {
        gint stamp;
        gpointer user_data;
        gpointer user_data2;
        gpointer user_data3;
    };

    struct GtkListStore;
    void gtk_list_store_append(GtkListStore* list_store, GtkTreeIter* iter);
    void gtk_list_store_set(GtkListStore* list_store, GtkTreeIter* iter, ...);
    GtkListStore* gtk_list_store_new(gint n_columns, ...);

    void gtk_list_store_clear(GtkListStore* list_store);

    struct GtkTreeView;

    void gtk_tree_view_set_model(GtkTreeView* tree_view, GtkTreeModel* tree_model);
    GtkTreeModel* gtk_tree_view_get_model(GtkTreeView* tree_view);
}
