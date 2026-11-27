#include "window_actions.h"
#include "window_icons.h"
#include "window_panels.h"

struct DrillGtkActions {
    GtkWindow *window;
    GtkWidget *entry, *tree, *bar, *open, *stop, *resume, *popup;
    GtkAccelGroup *accelerators;
    GtkIconTheme *theme;
    gulong theme_change;
    DrillGtkIcons *icons;
    GtkWidget *undo, *redo;
    GPtrArray *history;
    guint history_index;
    gboolean restoring;
    DrillModel *model;
    DrillGtkPanels *panels;
    uint64_t selection;
};

static void show_error(GtkWindow *window, const char *message) {
    GtkWidget *dialog = gtk_message_dialog_new(window, GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT,
                                               GTK_MESSAGE_ERROR, GTK_BUTTONS_CLOSE, "%s", message);
    g_signal_connect_swapped(dialog, "response", G_CALLBACK(gtk_widget_destroy), dialog);
    gtk_widget_show(dialog);
}

/* Association and terminal handlers may outlive the search window. */
static GWeakRef *weak_window(GtkWindow *window) {
    GWeakRef *weak = g_new(GWeakRef, 1);
    g_weak_ref_init(weak, window);
    return weak;
}

static void finish_action(GWeakRef *weak, const GError *error) {
    g_autoptr(GtkWindow) window = g_weak_ref_get(weak);
    if (error && window && gtk_widget_get_visible(GTK_WIDGET(window)))
        show_error(window, error->message);
    g_weak_ref_clear(weak);
    g_free(weak);
}

static void opened(GObject *source G_GNUC_UNUSED, GAsyncResult *result, gpointer data) {
    g_autoptr(GError) error = NULL;
    g_app_info_launch_default_for_uri_finish(result, &error);
    finish_action(data, error);
}

static GdkAppLaunchContext *launch_context(GtkWindow *window) {
    GdkDisplay *display = gtk_widget_get_display(GTK_WIDGET(window));
    GdkAppLaunchContext *context = gdk_display_get_app_launch_context(display);
    gdk_app_launch_context_set_timestamp(context, gtk_get_current_event_time());
    return context;
}

static void open_file(GtkWindow *window, GFile *file) {
    g_autofree char *uri = g_file_get_uri(file);
    g_autoptr(GdkAppLaunchContext) context = launch_context(window);
    g_app_info_launch_default_for_uri_async(uri, G_APP_LAUNCH_CONTEXT(context), NULL, opened, weak_window(window));
}

static void open_path(GtkWindow *window, const char *path, gboolean registered, const char *desktop_id) {
    if (registered) {
        g_autoptr(GDesktopAppInfo) app = drill_gtk_registered_app(desktop_id, path);
        if (!app) {
            show_error(window, "This application is no longer registered or available.");
            return;
        }
        g_autoptr(GdkAppLaunchContext) context = launch_context(window);
        g_autoptr(GError) error = NULL;
        if (!g_app_info_launch(G_APP_INFO(app), NULL, G_APP_LAUNCH_CONTEXT(context), &error))
            show_error(window, error->message);
    } else {
        g_autoptr(GFile) file = g_file_new_for_path(path);
        open_file(window, file);
    }
}

void drill_gtk_actions_open(DrillGtkActions *actions, const DrillRow *row) {
    /* GTK and GIO may emit signals during launch. Own the original path/ID first. */
    g_autofree char *path = g_strdup(row->path);
    g_autofree char *desktop_id = g_strdup(row->desktop_id);
    open_path(actions->window, path, row->registered_app, desktop_id);
}

static void chose_app(GtkDialog *dialog, gint response, gpointer data) {
    if (response == GTK_RESPONSE_OK || response == GTK_RESPONSE_ACCEPT) {
        GtkWindow *window = gtk_window_get_transient_for(GTK_WINDOW(dialog));
        g_autoptr(GAppInfo) app = gtk_app_chooser_get_app_info(GTK_APP_CHOOSER(dialog));
        if (app && window) {
            GList files = {.data = data};
            g_autoptr(GdkAppLaunchContext) context = launch_context(window);
            g_autoptr(GError) error = NULL;
            if (!g_app_info_launch(app, &files, G_APP_LAUNCH_CONTEXT(context), &error))
                show_error(window, error->message);
        }
    }
    gtk_widget_destroy(GTK_WIDGET(dialog));
}

static void open_with(GtkWindow *window, const char *path) {
    GFile *file = g_file_new_for_path(path);
    GtkWidget *dialog = gtk_app_chooser_dialog_new(window, GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT, file);
    gtk_window_set_title(GTK_WINDOW(dialog), "Open With");
    g_object_set_data_full(G_OBJECT(dialog), "drill-file", file, g_object_unref);
    g_signal_connect(dialog, "response", G_CALLBACK(chose_app), file);
    gtk_widget_show(dialog);
}

typedef struct {
    GWeakRef window;
    GFile *file;
} Reveal;

static void finish_reveal(Reveal *request, gboolean shown) {
    g_autoptr(GtkWindow) window = g_weak_ref_get(&request->window);
    if (!shown && window && gtk_widget_get_visible(GTK_WIDGET(window))) {
        g_autoptr(GFile) parent = g_file_get_parent(request->file);
        open_file(window, parent ? parent : request->file);
    }
    g_weak_ref_clear(&request->window);
    g_object_unref(request->file);
    g_free(request);
}

static void shown_items(GObject *source, GAsyncResult *result, gpointer data) {
    g_autoptr(GVariant) reply = g_dbus_connection_call_finish(G_DBUS_CONNECTION(source), result, NULL);
    finish_reveal(data, reply != NULL);
}

static void reveal_on_bus(GObject *source G_GNUC_UNUSED, GAsyncResult *result, gpointer data) {
    Reveal *request = data;
    g_autoptr(GDBusConnection) bus = g_bus_get_finish(result, NULL);
    if (!bus) {
        finish_reveal(request, FALSE);
        return;
    }
    g_autofree char *uri = g_file_get_uri(request->file);
    const char *uris[] = {uri, NULL};
    g_dbus_connection_call(bus, "org.freedesktop.FileManager1", "/org/freedesktop/FileManager1",
                           "org.freedesktop.FileManager1", "ShowItems", g_variant_new("(^ass)", uris, ""),
                           G_VARIANT_TYPE_UNIT, G_DBUS_CALL_FLAGS_NONE, 3000, NULL, shown_items, request);
}

static void reveal(GtkWindow *window, const char *path) {
    Reveal *request = g_new(Reveal, 1);
    g_weak_ref_init(&request->window, window);
    request->file = g_file_new_for_path(path);
    g_bus_get(G_BUS_TYPE_SESSION, NULL, reveal_on_bus, request);
}

static void terminal_closed(GObject *source, GAsyncResult *result, gpointer data) {
    g_autoptr(GError) error = NULL;
    g_subprocess_wait_check_finish(G_SUBPROCESS(source), result, &error);
    finish_action(data, error);
}

static void open_terminal(GtkWindow *window, const char *path, gboolean directory) {
    g_autofree char *cwd = directory || g_file_test(path, G_FILE_TEST_IS_DIR) ? g_strdup(path) : g_path_get_dirname(path);
    if (!g_file_test(cwd, G_FILE_TEST_IS_DIR)) {
        show_error(window, "The folder is no longer available.");
        return;
    }
    g_autoptr(GSubprocessLauncher) launcher = g_subprocess_launcher_new(G_SUBPROCESS_FLAGS_NONE);
    g_subprocess_launcher_set_cwd(launcher, cwd);
    static const char *const terminals[] = {
        "xdg-terminal-exec", "x-terminal-emulator", "gnome-terminal", "konsole", "xfce4-terminal", "xterm"
    };
    for (guint i = 0; i < G_N_ELEMENTS(terminals); i++) {
        /* Resolve on the original PATH before entering the selected folder. */
        g_autofree char *program = g_find_program_in_path(terminals[i]);
        if (!program)
            continue;
        g_autoptr(GError) error = NULL;
        g_autoptr(GSubprocess) process = g_subprocess_launcher_spawn(launcher, &error, program, NULL);
        if (process)
            g_subprocess_wait_check_async(process, NULL, terminal_closed, weak_window(window));
        else
            show_error(window, error->message);
        return;
    }
    show_error(window, "No supported terminal application was found.");
}

static void copy(GtkWindow *window, const char *text) {
    GtkClipboard *clipboard = gtk_widget_get_clipboard(GTK_WIDGET(window), GDK_SELECTION_CLIPBOARD);
    gtk_clipboard_set_text(clipboard, text, -1);
}

static void copy_path(GtkWindow *window, const char *path) {
    g_autofree char *display = g_filename_display_name(path);
    copy(window, display);
}

enum RowCommand { OPEN, OPEN_WITH, REVEAL, TERMINAL, COPY_PATH, COPY_DATE, COPY_SIZE };

typedef struct {
    GtkWindow *window;
    char *path, *desktop_id, *date, *size;
    gboolean directory, registered;
} MenuTarget;

static void free_target(gpointer data) {
    MenuTarget *target = data;
    g_free(target->path);
    g_free(target->desktop_id);
    g_free(target->date);
    g_free(target->size);
    g_free(target);
}

static void row_command(GtkWidget *item, gpointer data) {
    /* Each menu owns a snapshot, so sorting or replacing the query cannot retarget it. */
    g_autoptr(GtkWidget) menu = g_object_ref(gtk_widget_get_parent(item));
    MenuTarget *target = g_object_get_data(G_OBJECT(menu), "drill-target");
    switch ((enum RowCommand)GPOINTER_TO_INT(data)) {
    case OPEN: open_path(target->window, target->path, target->registered, target->desktop_id); break;
    case OPEN_WITH: open_with(target->window, target->path); break;
    case REVEAL: reveal(target->window, target->path); break;
    case TERMINAL: open_terminal(target->window, target->path, target->directory); break;
    case COPY_PATH: copy_path(target->window, target->path); break;
    case COPY_DATE: copy(target->window, target->date); break;
    case COPY_SIZE: copy(target->window, target->size); break;
    }
}

static void row_item(GtkWidget *menu, const char *label, enum RowCommand command) {
    GtkWidget *item;
    if (command == REVEAL || command == TERMINAL) {
        const char *icon = command == REVEAL ? "system-file-manager" : "utilities-terminal";
        item = gtk_menu_item_new();
        GtkWidget *line = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
        gtk_box_pack_start(GTK_BOX(line), gtk_image_new_from_icon_name(icon, GTK_ICON_SIZE_MENU), FALSE, FALSE, 0);
        gtk_box_pack_start(GTK_BOX(line), gtk_label_new(label), FALSE, FALSE, 0);
        gtk_container_add(GTK_CONTAINER(item), line);
        atk_object_set_name(gtk_widget_get_accessible(item), label);
    } else {
        item = gtk_menu_item_new_with_label(label);
    }
    g_signal_connect(item, "activate", G_CALLBACK(row_command), GINT_TO_POINTER(command));
    gtk_menu_shell_append(GTK_MENU_SHELL(menu), item);
}

static void discard_popup(DrillGtkActions *actions) {
    if (actions->popup) {
        gtk_widget_destroy(actions->popup);
        g_clear_object(&actions->popup);
    }
}

void drill_gtk_actions_popup(DrillGtkActions *actions, const DrillRow *row, GdkEvent *event) {
    MenuTarget *target = g_new0(MenuTarget, 1);
    *target = (MenuTarget) {
        .window = actions->window, .path = g_strdup(row->path), .desktop_id = g_strdup(row->desktop_id),
        .date = g_strdup(row->cells[3]), .size = g_strdup(row->cells[2]),
        .directory = row->directory, .registered = row->registered_app,
    };
    discard_popup(actions);
    GtkWidget *menu = actions->popup = g_object_ref_sink(gtk_menu_new());
    g_object_set_data_full(G_OBJECT(menu), "drill-target", target, free_target);
    gtk_menu_attach_to_widget(GTK_MENU(menu), actions->tree, NULL);
    row_item(menu, target->registered ? "Launch" : "Open", OPEN);
    row_item(menu, "Open With…", OPEN_WITH);
    row_item(menu, target->registered ? "Reveal Launcher File" : "Reveal in File Manager", REVEAL);
    row_item(menu, "Open Terminal Here", TERMINAL);
    gtk_menu_shell_append(GTK_MENU_SHELL(menu), gtk_separator_menu_item_new());
    row_item(menu, "Copy Full Path", COPY_PATH);
    row_item(menu, "Copy Date", COPY_DATE);
    row_item(menu, "Copy Size", COPY_SIZE);
    gtk_widget_show_all(menu);
    g_autoptr(GdkEvent) current_event = event ? NULL : gtk_get_current_event();
    if (!event)
        event = current_event;
    if (event && (event->type == GDK_BUTTON_PRESS || event->type == GDK_BUTTON_RELEASE))
        gtk_menu_popup_at_pointer(GTK_MENU(menu), event);
    else
        gtk_menu_popup_at_widget(GTK_MENU(menu), actions->tree, GDK_GRAVITY_CENTER, GDK_GRAVITY_NORTH_WEST, event);
}

enum Command {
    OPEN_SELECTED, CLOSE, UNDO, REDO, CUT, COPY, PASTE, SELECT_ALL,
    FIND, STOP, CONTINUE_SEARCH, INTERFACE, SYNTAX, ABOUT
};

static void history_buttons(DrillGtkActions *actions) {
    gtk_widget_set_sensitive(actions->undo, actions->history_index != 0);
    gtk_widget_set_sensitive(actions->redo, actions->history_index + 1 < actions->history->len);
}

static void edited(GtkEntry *entry, DrillGtkActions *actions) {
    if (actions->restoring)
        return;
    GPtrArray *history = actions->history;
    const char *text = gtk_entry_get_text(entry);
    if (!g_strcmp0(text, g_ptr_array_index(history, actions->history_index)))
        return;
    g_ptr_array_set_size(history, actions->history_index + 1);
    if (history->len == 64)
        g_ptr_array_remove_index(history, 0);
    actions->history_index = history->len;
    g_ptr_array_add(history, g_strdup(text));
    history_buttons(actions);
}

static void restore_query(DrillGtkActions *actions, gboolean redo) {
    if ((redo && actions->history_index + 1 == actions->history->len) || (!redo && !actions->history_index))
        return;
    if (redo)
        actions->history_index++;
    else
        actions->history_index--;
    actions->restoring = TRUE;
    gtk_widget_grab_focus(actions->entry);
    gtk_entry_set_text(GTK_ENTRY(actions->entry), g_ptr_array_index(actions->history, actions->history_index));
    gtk_editable_set_position(GTK_EDITABLE(actions->entry), -1);
    actions->restoring = FALSE;
    history_buttons(actions);
}

static void menu_command(GtkWidget *item, DrillGtkActions *actions) {
    enum Command command = GPOINTER_TO_INT(g_object_get_data(G_OBJECT(item), "drill-command"));
    GtkWidget *focus = gtk_window_get_focus(actions->window);
    GtkEditable *editable = GTK_IS_EDITABLE(focus) ? GTK_EDITABLE(focus) : NULL;
    DrillRow row;
    switch (command) {
    case OPEN_SELECTED:
        if (drill_row(actions->model, actions->selection, &row))
            drill_gtk_actions_open(actions, &row);
        break;
    case CLOSE: gtk_window_close(actions->window); break;
    case UNDO: case REDO: restore_query(actions, command == REDO); break;
    case CUT: if (editable) gtk_editable_cut_clipboard(editable); break;
    case PASTE: if (editable) gtk_editable_paste_clipboard(editable); break;
    case SELECT_ALL: if (editable) gtk_editable_select_region(editable, 0, -1); break;
    case COPY:
        if (editable)
            gtk_editable_copy_clipboard(editable);
        else if (focus == actions->tree && drill_row(actions->model, actions->selection, &row))
            copy_path(actions->window, row.path);
        break;
    case FIND:
        gtk_widget_grab_focus(actions->entry);
        gtk_editable_select_region(GTK_EDITABLE(actions->entry), 0, -1);
        break;
    case STOP: drill_stop(actions->model); break;
    case CONTINUE_SEARCH: drill_continue(actions->model); break;
    case INTERFACE: drill_gtk_show_interface(actions->panels); break;
    case SYNTAX: drill_gtk_show_syntax(actions->panels); break;
    case ABOUT:
        gtk_show_about_dialog(actions->window, "program-name", "Drill", "logo-icon-name", "drill", NULL);
        break;
    }
}

static GtkWidget *submenu(DrillGtkActions *actions, const char *label) {
    GtkWidget *item = gtk_menu_item_new_with_mnemonic(label);
    GtkWidget *menu = gtk_menu_new();
    gtk_menu_item_set_submenu(GTK_MENU_ITEM(item), menu);
    gtk_menu_shell_append(GTK_MENU_SHELL(actions->bar), item);
    return menu;
}

static GtkWidget *command_item(DrillGtkActions *actions, GtkWidget *menu, const char *label,
                               enum Command command, const char *shortcut) {
    GtkWidget *item = gtk_menu_item_new_with_mnemonic(label);
    g_object_set_data(G_OBJECT(item), "drill-command", GINT_TO_POINTER(command));
    g_signal_connect(item, "activate", G_CALLBACK(menu_command), actions);
    gtk_menu_shell_append(GTK_MENU_SHELL(menu), item);
    if (shortcut) {
        guint key;
        GdkModifierType modifiers;
        gtk_accelerator_parse(shortcut, &key, &modifiers);
        gtk_widget_add_accelerator(item, "activate", actions->accelerators, key, modifiers, GTK_ACCEL_VISIBLE);
    }
    return item;
}

static void build_menus(DrillGtkActions *actions) {
    GtkWidget *file = submenu(actions, "_File");
    actions->open = command_item(actions, file, "_Open Selection", OPEN_SELECTED, "<Primary>o");
    command_item(actions, file, "_Close Window", CLOSE, "<Primary>w");
    GtkWidget *edit = submenu(actions, "_Edit");
    actions->undo = command_item(actions, edit, "_Undo", UNDO, "<Primary>z");
    actions->redo = command_item(actions, edit, "_Redo", REDO, "<Primary><Shift>z");
    gtk_menu_shell_append(GTK_MENU_SHELL(edit), gtk_separator_menu_item_new());
    command_item(actions, edit, "Cu_t", CUT, "<Primary>x");
    command_item(actions, edit, "_Copy", COPY, "<Primary>c");
    command_item(actions, edit, "_Paste", PASTE, "<Primary>v");
    command_item(actions, edit, "Select _All", SELECT_ALL, "<Primary>a");
    GtkWidget *search = submenu(actions, "_Search");
    command_item(actions, search, "_Find", FIND, "<Primary>f");
    actions->stop = command_item(actions, search, "_Stop", STOP, NULL);
    actions->resume = command_item(actions, search, "_Continue", CONTINUE_SEARCH, NULL);
    GtkWidget *settings = submenu(actions, "Se_ttings");
    command_item(actions, settings, "_Interface…", INTERFACE, "<Primary>comma");
    GtkWidget *help = submenu(actions, "_Help");
    command_item(actions, help, "_Syntax", SYNTAX, "F1");
    command_item(actions, help, "_About Drill", ABOUT, NULL);
}

static void icons_changed(void *data) {
    DrillGtkActions *actions = data;
    drill_gtk_icon_cache_clear(actions->icons);
    gtk_widget_queue_draw(actions->tree);
}

static void theme_changed(GtkIconTheme *theme G_GNUC_UNUSED, gpointer data) {
    icons_changed(data);
}

GdkPixbuf *drill_gtk_row_icon(DrillGtkActions *actions, DrillModel *model, uint64_t id, const DrillRow *row) {
    return drill_gtk_icon_get(actions->icons, model, id, row, drill_gtk_exe_icons(actions->panels),
                              drill_gtk_appimage_icons(actions->panels));
}

DrillGtkActions *drill_gtk_actions_new(GtkWindow *window, GtkWidget *search_entry, GtkWidget *tree_view,
                                      DrillModel *model) {
    DrillGtkActions *actions = g_new0(DrillGtkActions, 1);
    actions->window = window;
    actions->entry = search_entry;
    actions->tree = tree_view;
    actions->model = model;
    actions->icons = drill_gtk_icon_cache_new(tree_view);
    actions->panels = drill_gtk_panels_new(window, icons_changed, actions);
    actions->theme = gtk_icon_theme_get_default();
    actions->theme_change = g_signal_connect(actions->theme, "changed", G_CALLBACK(theme_changed), actions);
    actions->bar = gtk_menu_bar_new();
    actions->accelerators = gtk_accel_group_new();
    gtk_window_add_accel_group(window, actions->accelerators);
    build_menus(actions);
    actions->history = g_ptr_array_new_with_free_func(g_free);
    g_ptr_array_add(actions->history, g_strdup(gtk_entry_get_text(GTK_ENTRY(search_entry))));
    history_buttons(actions);
    g_signal_connect(search_entry, "changed", G_CALLBACK(edited), actions);
    return actions;
}

GtkWidget *drill_gtk_actions_menubar(DrillGtkActions *actions) {
    return actions->bar;
}

void drill_gtk_actions_select(DrillGtkActions *actions, uint64_t id) {
    actions->selection = id;
    gtk_widget_set_sensitive(actions->open, id != 0);
}

void drill_gtk_actions_update(DrillGtkActions *actions, const DrillState *state) {
    uint64_t id = state->selected_index < 0 ? 0 : drill_row_id(actions->model, (size_t)state->selected_index);
    /* Consume the borrowed snapshot before calling GTK callbacks. */
    gboolean stop = state->can_stop, resume = state->can_continue;
    drill_gtk_actions_select(actions, id);
    gtk_widget_set_sensitive(actions->stop, stop);
    gtk_widget_set_sensitive(actions->resume, resume);
    drill_gtk_panels_update(actions->panels);
}

/* Window and its child widgets have been destroyed by the caller. */
void drill_gtk_actions_free(DrillGtkActions *actions) {
    g_signal_handler_disconnect(actions->theme, actions->theme_change);
    discard_popup(actions);
    drill_gtk_panels_free(actions->panels);
    drill_gtk_icon_cache_free(actions->icons);
    g_ptr_array_unref(actions->history);
    g_object_unref(actions->accelerators);
    g_free(actions);
}
