#include "window_table.h"

struct DrillGtkTable {
    GtkTreeView *view;
    GtkListStore *positions;
    GtkWidget *entry;
    DrillModel *model;
    DrillGtkActions *actions;
    int count;
    int sort_column;
    bool ascending, applying;
    uint64_t first_press;
    GdkRGBA alternate;
};

static int iter_index(GtkTreeModel *model, GtkTreeIter *iter) {
    int index;
    gtk_tree_model_get(model, iter, 0, &index, -1);
    return index;
}

static int selected_index(DrillGtkTable *table) {
    GtkTreeModel *model;
    GtkTreeIter iter;
    GtkTreeSelection *selection = gtk_tree_view_get_selection(table->view);
    return gtk_tree_selection_get_selected(selection, &model, &iter)
        ? iter_index(model, &iter) : -1;
}

static void select_index(DrillGtkTable *table, int index) {
    GtkTreeSelection *selection = gtk_tree_view_get_selection(table->view);
    if (index < 0) {
        gtk_tree_selection_unselect_all(selection);
        return;
    }
    GtkTreePath *path = gtk_tree_path_new_from_indices(index, -1);
    gtk_tree_view_set_cursor(table->view, path, NULL, FALSE);
    gtk_tree_view_scroll_to_cell(table->view, path, NULL, FALSE, 0, 0);
    gtk_tree_path_free(path);
}

void drill_gtk_table_move(DrillGtkTable *table, int offset) {
    if (table->count)
        select_index(table, CLAMP(selected_index(table) + offset, -1, table->count - 1));
}

static void open_id(DrillGtkTable *table, uint64_t id) {
    DrillRow row;
    if (id && drill_row(table->model, id, &row))
        drill_gtk_actions_open(table->actions, &row);
}

void drill_gtk_table_open_selected(DrillGtkTable *table) {
    int index = selected_index(table);
    if (index >= 0)
        open_id(table, drill_row_id(table->model, index));
}

static void selection_changed(GtkTreeSelection *selection G_GNUC_UNUSED, DrillGtkTable *table) {
    if (table->applying || gtk_widget_in_destruction(GTK_WIDGET(table->view))) return;
    int index = selected_index(table);
    uint64_t id = index < 0 ? 0 : drill_row_id(table->model, index);
    drill_select(table->model, id);
    drill_gtk_actions_select(table->actions, id);
}

static void capture_press(GtkGestureMultiPress *gesture G_GNUC_UNUSED, int count,
                          double x, double y, DrillGtkTable *table) {
    if (count != 1) return;
    int bin_x, bin_y;
    GtkTreePath *path = NULL;
    gtk_tree_view_convert_widget_to_bin_window_coords(table->view, (int)x, (int)y, &bin_x, &bin_y);
    gtk_tree_view_get_path_at_pos(table->view, bin_x, bin_y, &path, NULL, NULL, NULL);
    table->first_press = path ? drill_row_id(table->model, gtk_tree_path_get_indices(path)[0]) : 0;
    if (path) gtk_tree_path_free(path);
}

static void row_activated(GtkTreeView *view G_GNUC_UNUSED, GtkTreePath *path,
                          GtkTreeViewColumn *column G_GNUC_UNUSED, DrillGtkTable *table) {
    uint64_t id = drill_row_id(table->model, gtk_tree_path_get_indices(path)[0]);
    g_autoptr(GdkEvent) event = gtk_get_current_event();
    bool pointer = event && (event->type == GDK_BUTTON_PRESS || event->type == GDK_2BUTTON_PRESS ||
                             event->type == GDK_BUTTON_RELEASE || event->type == GDK_TOUCH_BEGIN ||
                             event->type == GDK_TOUCH_END);
    if (!pointer || id == table->first_press)
        open_id(table, id);
}

static gboolean button_press(GtkWidget *widget, GdkEventButton *event, DrillGtkTable *table) {
    if (event->window != gtk_tree_view_get_bin_window(table->view)) return FALSE;
    GtkTreePath *path = NULL;
    gtk_tree_view_get_path_at_pos(table->view, (int)event->x, (int)event->y, &path, NULL, NULL, NULL);
    int index = path ? gtk_tree_path_get_indices(path)[0] : -1;
    uint64_t id = index < 0 ? 0 : drill_row_id(table->model, index);
    if (path) gtk_tree_path_free(path);
    if (event->type == GDK_BUTTON_PRESS && id && gdk_event_triggers_context_menu((GdkEvent *)event)) {
        gtk_widget_grab_focus(widget);
        select_index(table, index);
        DrillRow row;
        if (drill_row(table->model, id, &row))
            drill_gtk_actions_popup(table->actions, &row, (GdkEvent *)event);
        return TRUE;
    }
    return FALSE;
}

static gboolean keyboard_popup(GtkWidget *widget G_GNUC_UNUSED, DrillGtkTable *table) {
    int index = selected_index(table);
    DrillRow row;
    if (index < 0 || !drill_row(table->model, drill_row_id(table->model, index), &row))
        return FALSE;
    drill_gtk_actions_popup(table->actions, &row, NULL);
    return TRUE;
}

static gboolean table_key(GtkWidget *widget G_GNUC_UNUSED, GdkEventKey *event, DrillGtkTable *table) {
    if ((event->state & gtk_accelerator_get_default_mod_mask()) == 0 &&
        (event->keyval == GDK_KEY_Up || event->keyval == GDK_KEY_KP_Up) && selected_index(table) == 0) {
        select_index(table, -1);
        gtk_widget_grab_focus(table->entry);
        return TRUE;
    }
    return FALSE;
}

static gboolean tooltip(GtkWidget *widget G_GNUC_UNUSED, gint x, gint y, gboolean keyboard,
                        GtkTooltip *tip, DrillGtkTable *table) {
    GtkTreeIter iter;
    GtkTreeModel *model;
    GtkTreePath *path;
    if (!gtk_tree_view_get_tooltip_context(table->view, &x, &y, keyboard, &model, &path, &iter))
        return FALSE;
    DrillRow row;
    bool found = drill_row(table->model, drill_row_id(table->model, iter_index(model, &iter)), &row);
    if (found) {
        char *display = g_filename_display_name(row.path);
        gtk_tooltip_set_text(tip, display);
        g_free(display);
        gtk_tree_view_set_tooltip_row(table->view, tip, path);
    }
    gtk_tree_path_free(path);
    return found;
}

static void style_updated(GtkWidget *widget, DrillGtkTable *table) {
    GtkStyleContext *style = gtk_widget_get_style_context(widget);
    GdkRGBA text;
    gtk_style_context_get_color(style, GTK_STATE_FLAG_NORMAL, &text);
    // Blend the theme text over its actual base, including custom and dark themes.
    table->alternate = text;
    table->alternate.alpha = 0.055;
}

static void display_cell(GtkTreeViewColumn *column, GtkCellRenderer *cell,
                         GtkTreeModel *model, GtkTreeIter *iter, gpointer data) {
    DrillGtkTable *table = data;
    int index = iter_index(model, iter);
    uint64_t id = drill_row_id(table->model, index);
    DrillRow row;
    bool found = id && drill_row(table->model, id, &row);
    gboolean striped = (index & 1) && !gtk_tree_selection_iter_is_selected(
        gtk_tree_view_get_selection(table->view), iter);
    g_object_set(cell, "cell-background-rgba", &table->alternate,
                 "cell-background-set", striped, NULL);
    if (GTK_IS_CELL_RENDERER_PIXBUF(cell)) {
        GdkPixbuf *icon = found ? drill_gtk_row_icon(table->actions, table->model, id, &row) : NULL;
        g_object_set(cell, "pixbuf", icon, NULL);
        g_clear_object(&icon);
    } else {
        unsigned field = GPOINTER_TO_UINT(g_object_get_data(G_OBJECT(column), "drill-column"));
        g_object_set(cell, "text", found ? row.cells[field] : "", NULL);
    }
}

static void sort_clicked(GtkTreeViewColumn *column, DrillGtkTable *table) {
    int field = GPOINTER_TO_INT(g_object_get_data(G_OBJECT(column), "drill-column"));
    if (table->sort_column >= 0)
        gtk_tree_view_column_set_sort_indicator(gtk_tree_view_get_column(table->view, table->sort_column), FALSE);
    table->ascending = field != table->sort_column || !table->ascending;
    table->sort_column = field;
    gtk_tree_view_column_set_sort_order(column, table->ascending ? GTK_SORT_ASCENDING : GTK_SORT_DESCENDING);
    gtk_tree_view_column_set_sort_indicator(column, TRUE);
    drill_sort(table->model, field);
    // Sorting changes which file occupies each GTK position before the next timer.
    DrillState state = drill_tick(table->model);
    drill_gtk_table_update(table, &state);
}

static void add_column(DrillGtkTable *table, unsigned field, const char *title, int width, int minimum) {
    GtkTreeViewColumn *column = gtk_tree_view_column_new();
    g_object_set_data(G_OBJECT(column), "drill-column", GUINT_TO_POINTER(field));
    gtk_tree_view_column_set_title(column, title);
    gtk_tree_view_column_set_sizing(column, GTK_TREE_VIEW_COLUMN_FIXED);
    gtk_tree_view_column_set_fixed_width(column, width);
    gtk_tree_view_column_set_min_width(column, minimum);
    gtk_tree_view_column_set_resizable(column, TRUE);
    gtk_tree_view_column_set_expand(column, field < 2);
    gtk_tree_view_column_set_clickable(column, TRUE);
    if (field == 0) {
        GtkCellRenderer *icon = gtk_cell_renderer_pixbuf_new();
        gtk_cell_renderer_set_fixed_size(icon, 42, 36);
        gtk_tree_view_column_pack_start(column, icon, FALSE);
        gtk_tree_view_column_set_cell_data_func(column, icon, display_cell, table, NULL);
    }
    GtkCellRenderer *text = gtk_cell_renderer_text_new();
    g_object_set(text, "ellipsize", field == 1 ? PANGO_ELLIPSIZE_MIDDLE : PANGO_ELLIPSIZE_END,
                 "xpad", 5u, NULL);
    gtk_tree_view_column_pack_start(column, text, TRUE);
    gtk_tree_view_column_set_cell_data_func(column, text, display_cell, table, NULL);
    g_signal_connect(column, "clicked", G_CALLBACK(sort_clicked), table);
    gtk_tree_view_append_column(table->view, column);
}

DrillGtkTable *drill_gtk_table_new(GtkTreeView *view, GtkWidget *entry,
                                  DrillModel *model, DrillGtkActions *actions) {
    DrillGtkTable *table = g_new0(DrillGtkTable, 1);
    table->model = model;
    table->actions = actions;
    table->entry = entry;
    table->view = view;
    table->sort_column = -1;
    // GTK maintains scrolling, selection, and accessibility for the positions.
    // Only rendered cells request text or icons from the current sorted model.
    table->positions = gtk_list_store_new(1, G_TYPE_INT);
    gtk_tree_view_set_model(view, GTK_TREE_MODEL(table->positions));
    g_object_unref(table->positions);
    gtk_tree_view_set_enable_search(view, FALSE);
    gtk_tree_view_set_fixed_height_mode(view, TRUE);
    gtk_widget_set_has_tooltip(GTK_WIDGET(view), TRUE);
    add_column(table, 0, "Name", 208, 80);
    add_column(table, 1, "Path", 223, 80);
    add_column(table, 2, "Size", 65, 52);
    add_column(table, 3, "Date", 166, 90);
    style_updated(GTK_WIDGET(view), table);
    g_signal_connect(view, "style-updated", G_CALLBACK(style_updated), table);
    g_signal_connect(view, "query-tooltip", G_CALLBACK(tooltip), table);
    g_signal_connect(view, "popup-menu", G_CALLBACK(keyboard_popup), table);
    g_signal_connect(view, "button-press-event", G_CALLBACK(button_press), table);
    g_signal_connect(view, "key-press-event", G_CALLBACK(table_key), table);
    // Observe the first press before GtkTreeView decides to activate a row.
    // Streaming must never open a different file that moved under the pointer.
    GtkGesture *click = gtk_gesture_multi_press_new(GTK_WIDGET(view));
    gtk_event_controller_set_propagation_phase(GTK_EVENT_CONTROLLER(click), GTK_PHASE_CAPTURE);
    g_signal_connect(click, "pressed", G_CALLBACK(capture_press), table);
    g_object_set_data_full(G_OBJECT(view), "drill-click", click, g_object_unref);
    g_signal_connect(view, "row-activated", G_CALLBACK(row_activated), table);
    g_signal_connect(gtk_tree_view_get_selection(view), "changed", G_CALLBACK(selection_changed), table);
    g_object_set_data_full(G_OBJECT(view), "drill-table", table, g_free);
    return table;
}

void drill_gtk_table_update(DrillGtkTable *table, const DrillState *state) {
    table->applying = true;
    int count = MIN(state->count, (size_t)G_MAXINT);
    GtkTreeIter iter;
    if (count == 0 && table->count > 0) {
        gtk_list_store_clear(table->positions);
    } else if (count < table->count &&
               gtk_tree_model_iter_nth_child(GTK_TREE_MODEL(table->positions), &iter, NULL, count)) {
        while (gtk_list_store_remove(table->positions, &iter)) {}
    }
    for (int i = table->count; i < count; ++i)
        gtk_list_store_insert_with_values(table->positions, &iter, -1, 0, i, -1);
    table->count = count;
    int selected = state->selected_index >= 0 && state->selected_index < count ? (int)state->selected_index : -1;
    if (selected != selected_index(table))
        select_index(table, selected);
    table->applying = false;
    // An insertion in the Rust sort order can replace an existing cell at the
    // same GTK position. Refresh native accessibility and paint for visible rows.
    GtkTreePath *first = NULL, *last = NULL;
    GtkTreeModel *positions = GTK_TREE_MODEL(table->positions);
    if (gtk_tree_view_get_visible_range(table->view, &first, &last)) {
        while (gtk_tree_path_compare(first, last) <= 0 && gtk_tree_model_get_iter(positions, &iter, first)) {
            gtk_tree_model_row_changed(positions, first, &iter);
            gtk_tree_path_next(first);
        }
        gtk_tree_path_free(first);
        gtk_tree_path_free(last);
    }
    gtk_widget_queue_draw(GTK_WIDGET(table->view));
}
