#include "window_table.h"

typedef struct {
    DrillModel *model;
    GtkWidget *window, *entry, *scope, *view, *status, *stop, *resume;
    DrillGtkActions *actions;
    DrillGtkTable *table;
    uint64_t revision, icon_revision;
    guint timer;
    bool composing;
} SearchWindow;

static void accessible_name(GtkWidget *widget, const char *name) {
    atk_object_set_name(gtk_widget_get_accessible(widget), name);
}

static gboolean refresh(gpointer data) {
    SearchWindow *window = data;
    DrillState state = drill_tick(window->model);
    if (window->revision != state.revision) {
        window->revision = state.revision;
        gtk_label_set_text(GTK_LABEL(window->status), state.status);
        gtk_widget_set_sensitive(window->stop, state.can_stop);
        gtk_widget_set_visible(window->resume, state.can_continue);
        drill_gtk_table_update(window->table, &state);
    }
    // The desktop appearance portal can publish a change while the search is idle.
    drill_gtk_actions_update(window->actions, &state);
    if (window->icon_revision != state.icon_revision) {
        window->icon_revision = state.icon_revision;
        gtk_widget_queue_draw(window->view);
    }
    return G_SOURCE_CONTINUE;
}

static void search_changed(GtkWidget *widget G_GNUC_UNUSED, SearchWindow *window) {
    bool apps = gtk_combo_box_get_active(GTK_COMBO_BOX(window->scope)) == 1;
    gtk_entry_set_placeholder_text(GTK_ENTRY(window->entry), apps ? "Search apps" : "Search files");
    drill_query(window->model, gtk_entry_get_text(GTK_ENTRY(window->entry)), apps);
    refresh(window);
}

static void stop_search(GtkButton *button G_GNUC_UNUSED, SearchWindow *window) {
    drill_stop(window->model);
    refresh(window);
}

static void continue_search(GtkButton *button G_GNUC_UNUSED, SearchWindow *window) {
    drill_continue(window->model);
    refresh(window);
}

static void preedit_changed(GtkEntry *entry G_GNUC_UNUSED, const char *text, SearchWindow *window) {
    window->composing = text && text[0];
}

static void entry_activated(GtkEntry *entry G_GNUC_UNUSED, SearchWindow *window) {
    drill_gtk_table_open_selected(window->table);
}

static gboolean window_key(GtkWidget *widget G_GNUC_UNUSED, GdkEventKey *event, SearchWindow *window) {
    if ((event->state & gtk_accelerator_get_default_mod_mask()) || window->composing)
        return FALSE;
    if (event->keyval == GDK_KEY_Escape) {
        gtk_window_close(GTK_WINDOW(window->window));
        return TRUE;
    }
    if (gtk_widget_has_focus(window->entry)) {
        switch (event->keyval) {
        case GDK_KEY_Up: case GDK_KEY_KP_Up:
            drill_gtk_table_move(window->table, -1);
            return TRUE;
        case GDK_KEY_Down: case GDK_KEY_KP_Down:
            drill_gtk_table_move(window->table, 1);
            return TRUE;
        }
    }
    return FALSE;
}

static void window_closed(GtkWidget *widget G_GNUC_UNUSED, SearchWindow *window) {
    if (window->timer) {
        g_source_remove(window->timer);
        window->timer = 0;
    }
    drill_stop(window->model);
    gtk_main_quit();
}

static GtkWidget *search_bar(SearchWindow *window) {
    GtkWidget *bar = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 12);
    gtk_container_set_border_width(GTK_CONTAINER(bar), 12);
    window->entry = gtk_search_entry_new();
    gtk_entry_set_placeholder_text(GTK_ENTRY(window->entry), "Search files");
    accessible_name(window->entry, "Search");
    gtk_box_pack_start(GTK_BOX(bar), window->entry, TRUE, TRUE, 0);
    window->scope = gtk_combo_box_text_new();
    gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(window->scope), "Files");
    gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(window->scope), "Apps");
    gtk_combo_box_set_active(GTK_COMBO_BOX(window->scope), 0);
    accessible_name(window->scope, "Search in");
    gtk_box_pack_start(GTK_BOX(bar), window->scope, FALSE, FALSE, 0);
    g_signal_connect(window->scope, "changed", G_CALLBACK(search_changed), window);
    g_signal_connect(window->entry, "changed", G_CALLBACK(search_changed), window);
    g_signal_connect(window->entry, "preedit-changed", G_CALLBACK(preedit_changed), window);
    g_signal_connect(window->entry, "activate", G_CALLBACK(entry_activated), window);
    return bar;
}

static GtkWidget *status_bar(SearchWindow *window) {
    GtkWidget *bar = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
    gtk_widget_set_margin_start(bar, 12);
    gtk_widget_set_margin_end(bar, 12);
    gtk_widget_set_margin_top(bar, 8);
    gtk_widget_set_margin_bottom(bar, 8);
    window->status = gtk_label_new("");
    gtk_label_set_xalign(GTK_LABEL(window->status), 0);
    gtk_label_set_ellipsize(GTK_LABEL(window->status), PANGO_ELLIPSIZE_END);
    gtk_box_pack_start(GTK_BOX(bar), window->status, TRUE, TRUE, 0);
    window->resume = gtk_button_new_with_label("Continue");
    gtk_widget_set_no_show_all(window->resume, TRUE);
    gtk_box_pack_start(GTK_BOX(bar), window->resume, FALSE, FALSE, 0);
    window->stop = gtk_button_new_with_label("Stop");
    gtk_box_pack_start(GTK_BOX(bar), window->stop, FALSE, FALSE, 0);
    g_signal_connect(window->stop, "clicked", G_CALLBACK(stop_search), window);
    g_signal_connect(window->resume, "clicked", G_CALLBACK(continue_search), window);
    return bar;
}

int drill_native_run(DrillModel *model) {
    g_set_prgname("drill");
    g_set_application_name("Drill");
    if (!gtk_init_check(NULL, NULL)) {
        g_printerr("Drill could not connect to the desktop display.\n");
        return 1;
    }

    SearchWindow window = {.model = model};
    window.window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_title(GTK_WINDOW(window.window), "Drill");
    gtk_window_set_icon_name(GTK_WINDOW(window.window), "drill");
    gtk_window_set_default_size(GTK_WINDOW(window.window), 680, 470);
    gtk_widget_set_size_request(window.window, 440, 290);
    gtk_window_set_position(GTK_WINDOW(window.window), GTK_WIN_POS_CENTER);
    GtkWidget *layout = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    gtk_container_add(GTK_CONTAINER(window.window), layout);
    GtkWidget *bar = search_bar(&window);
    window.view = gtk_tree_view_new();
    accessible_name(window.view, "Search results");
    window.actions = drill_gtk_actions_new(GTK_WINDOW(window.window), window.entry, window.view, model);
    window.table = drill_gtk_table_new(GTK_TREE_VIEW(window.view), window.entry, model, window.actions);
    gtk_box_pack_start(GTK_BOX(layout), drill_gtk_actions_menubar(window.actions), FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(layout), bar, FALSE, FALSE, 0);
    GtkWidget *scroll = gtk_scrolled_window_new(NULL, NULL);
    gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scroll), GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
    gtk_scrolled_window_set_shadow_type(GTK_SCROLLED_WINDOW(scroll), GTK_SHADOW_IN);
    gtk_container_add(GTK_CONTAINER(scroll), window.view);
    gtk_box_pack_start(GTK_BOX(layout), scroll, TRUE, TRUE, 0);
    gtk_box_pack_start(GTK_BOX(layout), status_bar(&window), FALSE, FALSE, 0);
    g_signal_connect(window.window, "key-press-event", G_CALLBACK(window_key), &window);
    g_signal_connect(window.window, "destroy", G_CALLBACK(window_closed), &window);

    gtk_window_set_focus(GTK_WINDOW(window.window), window.entry);
    refresh(&window);
    gtk_widget_show_all(window.window);
    window.timer = g_timeout_add(25, refresh, &window);
    gtk_main();
    drill_gtk_actions_free(window.actions);
    return 0;
}
