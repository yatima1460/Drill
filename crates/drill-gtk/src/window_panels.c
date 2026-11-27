#include "window_panels.h"
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

// desktop_theme.c publishes 0 for unavailable, 1 for light and 2 for dark.
void drill_desktop_theme_observe(GCancellable *stop, void (*publish)(gint, gpointer), gpointer data);
enum Appearance { AUTOMATIC, LIGHT, DARK };
static const char *const appearances[] = {"Auto", "Light", "Dark"};
static const char *const icon_keys[] = {"embedded_exe_icons", "embedded_appimage_icons"};

struct DrillGtkPanels {
    GtkWindow *parent;
    GtkWidget *interface;
    GtkWidget *syntax;
    void (*icons_changed)(void *);
    void *context;
    char *config;
    enum Appearance appearance;
    gboolean icons[2];
    GCancellable *stop;
    GThread *observer;
    gint portal_theme; // Written by the observer. Read on the GTK thread.
    gint applied;
};

static void save_preferences(DrillGtkPanels *panels) {
    g_autofree char *dir = g_path_get_dirname(panels->config);
    if (g_mkdir_with_parents(dir, 0700) != 0) {
        g_warning("Could not create the Drill settings directory: %s", g_strerror(errno));
        return;
    }
    g_autoptr(GKeyFile) file = g_key_file_new();
    g_key_file_set_string(file, "Interface", "appearance", appearances[panels->appearance]);
    for (guint i = 0; i < G_N_ELEMENTS(icon_keys); i++)
        g_key_file_set_boolean(file, "Interface", icon_keys[i], panels->icons[i]);
    g_autoptr(GError) error = NULL;
    if (!g_key_file_save_to_file(file, panels->config, &error))
        g_warning("Could not save Drill preferences: %s", error->message);
}

static void set_appearance(DrillGtkPanels *panels, const char *value) {
    for (guint i = 0; i < G_N_ELEMENTS(appearances); i++) {
        if (g_strcmp0(value, appearances[i]) == 0)
            panels->appearance = (enum Appearance)i;
    }
}

// The released eframe version writes a pretty-printed map of string pairs.
// Read only its three known settings. Never edit the old file.
static void import_released_preferences(DrillGtkPanels *panels) {
    g_autofree char *path = g_build_filename(g_get_user_data_dir(), "drill", "app.ron", NULL);
    int fd = open(path, O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC);
    if (fd < 0)
        return;
    struct stat info;
    char bytes[64 * 1024 + 1];
    ssize_t len = -1;
    if (fstat(fd, &info) == 0 && S_ISREG(info.st_mode) && info.st_size > 0 &&
        info.st_size < (off_t)sizeof(bytes)) {
        len = read(fd, bytes, sizeof(bytes) - 1);
    }
    close(fd);
    if (len <= 0 || len != info.st_size)
        return;
    bytes[len] = '\0';
    g_auto(GStrv) lines = g_strsplit(bytes, "\n", -1);
    gboolean imported = FALSE;
    for (char **line = lines; *line; line++) {
        char key[48], value[16];
        int end = 0;
        char *pair = g_strstrip(*line);
        if (sscanf(pair, "\"%47[a-z_]\": \"%15[a-zA-Z]\",%n", key, value, &end) != 2 ||
            end == 0 || pair[end] != '\0')
            continue;
        if (g_str_equal(key, "appearance")) {
            set_appearance(panels, value);
            imported = TRUE;
        }
        for (guint i = 0; i < G_N_ELEMENTS(icon_keys); i++) {
            if (g_str_equal(key, icon_keys[i]) &&
                (g_str_equal(value, "true") || g_str_equal(value, "false"))) {
                panels->icons[i] = g_str_equal(value, "true");
                imported = TRUE;
            }
        }
    }
    if (imported)
        save_preferences(panels);
}

static void read_preferences(DrillGtkPanels *panels) {
    g_autoptr(GKeyFile) file = g_key_file_new();
    g_autoptr(GError) error = NULL;
    if (!g_key_file_load_from_file(file, panels->config, G_KEY_FILE_NONE, &error)) {
        if (g_error_matches(error, G_FILE_ERROR, G_FILE_ERROR_NOENT))
            import_released_preferences(panels);
        return;
    }
    g_autofree char *appearance = g_key_file_get_string(file, "Interface", "appearance", NULL);
    set_appearance(panels, appearance);
    for (guint i = 0; i < G_N_ELEMENTS(icon_keys); i++) {
        gboolean enabled = g_key_file_get_boolean(file, "Interface", icon_keys[i], &error);
        if (!error)
            panels->icons[i] = enabled;
        g_clear_error(&error);
    }
}

static void publish_theme(gint theme, gpointer data) {
    DrillGtkPanels *panels = data;
    g_atomic_int_set(&panels->portal_theme, theme);
}

static gpointer observe_theme(gpointer data) {
    DrillGtkPanels *panels = data;
    drill_desktop_theme_observe(panels->stop, publish_theme, panels);
    return NULL;
}

void drill_gtk_panels_update(DrillGtkPanels *panels) {
    gint theme = panels->appearance == AUTOMATIC ? g_atomic_int_get(&panels->portal_theme)
                                                  : (int)panels->appearance;
    if (panels->applied == theme)
        return;
    GtkSettings *settings = gtk_widget_get_settings(GTK_WIDGET(panels->parent));
    if (panels->appearance == AUTOMATIC)
        gtk_settings_reset_property(settings, "gtk-theme-name");
    else
        g_object_set(settings, "gtk-theme-name", "Adwaita", NULL);
    if (theme == AUTOMATIC)
        gtk_settings_reset_property(settings, "gtk-application-prefer-dark-theme");
    else
        g_object_set(settings, "gtk-application-prefer-dark-theme", theme == DARK, NULL);
    panels->applied = theme;
}

DrillGtkPanels *drill_gtk_panels_new(GtkWindow *parent, void (*icons_changed)(void *), void *context) {
    DrillGtkPanels *panels = g_new0(DrillGtkPanels, 1);
    panels->parent = parent;
    panels->context = context;
    panels->icons_changed = icons_changed;
    panels->icons[0] = panels->icons[1] = TRUE;
    panels->config = g_build_filename(g_get_user_config_dir(), "drill", "interface.ini", NULL);
    read_preferences(panels);
    panels->applied = -1;
    drill_gtk_panels_update(panels);
    panels->stop = g_cancellable_new();
    panels->observer = g_thread_new("drill-appearance", observe_theme, panels);
    return panels;
}

void drill_gtk_panels_free(DrillGtkPanels *panels) {
    g_cancellable_cancel(panels->stop);
    g_thread_join(panels->observer);
    g_object_unref(panels->stop);
    if (panels->interface)
        gtk_widget_destroy(panels->interface);
    if (panels->syntax)
        gtk_widget_destroy(panels->syntax);
    g_free(panels->config);
    g_free(panels);
}

gboolean drill_gtk_exe_icons(const DrillGtkPanels *panels) { return panels->icons[0]; }
gboolean drill_gtk_appimage_icons(const DrillGtkPanels *panels) { return panels->icons[1]; }

static GtkWidget *create_dialog(DrillGtkPanels *panels, GtkWidget **slot, const char *title) {
    *slot = gtk_dialog_new_with_buttons(title, panels->parent, GTK_DIALOG_DESTROY_WITH_PARENT,
                                        "_Close", GTK_RESPONSE_CLOSE, NULL);
    g_signal_connect(*slot, "destroy", G_CALLBACK(gtk_widget_destroyed), slot);
    g_signal_connect_swapped(*slot, "response", G_CALLBACK(gtk_widget_destroy), *slot);
    return gtk_dialog_get_content_area(GTK_DIALOG(*slot));
}

static void changed_appearance(GtkToggleButton *button, DrillGtkPanels *panels) {
    if (!gtk_toggle_button_get_active(button))
        return;
    set_appearance(panels, gtk_button_get_label(GTK_BUTTON(button)));
    panels->applied = -1;
    drill_gtk_panels_update(panels);
    save_preferences(panels);
}

static void changed_icons(GtkToggleButton *button, DrillGtkPanels *panels) {
    guint index = GPOINTER_TO_UINT(g_object_get_data(G_OBJECT(button), "choice"));
    panels->icons[index] = gtk_toggle_button_get_active(button);
    save_preferences(panels);
    panels->icons_changed(panels->context);
}

static GtkWidget *section(GtkWidget *box, const char *markup) {
    GtkWidget *label = gtk_label_new(NULL);
    gtk_label_set_markup(GTK_LABEL(label), markup);
    gtk_label_set_xalign(GTK_LABEL(label), 0);
    gtk_label_set_line_wrap(GTK_LABEL(label), TRUE);
    gtk_label_set_selectable(GTK_LABEL(label), TRUE);
    gtk_box_pack_start(GTK_BOX(box), label, FALSE, FALSE, 0);
    return label;
}

void drill_gtk_show_interface(DrillGtkPanels *panels) {
    if (panels->interface) {
        gtk_window_present(GTK_WINDOW(panels->interface));
        return;
    }
    GtkWidget *content = create_dialog(panels, &panels->interface, "Interface");
    gtk_window_set_default_size(GTK_WINDOW(panels->interface), 380, -1);
    gtk_container_set_border_width(GTK_CONTAINER(content), 16);
    gtk_box_set_spacing(GTK_BOX(content), 8);
    section(content, "<b>Appearance</b>");
    GtkWidget *choices = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 12);
    gtk_box_pack_start(GTK_BOX(content), choices, FALSE, FALSE, 0);
    GtkRadioButton *first = NULL;
    for (guint i = 0; i < G_N_ELEMENTS(appearances); i++) {
        GtkWidget *choice = gtk_radio_button_new_with_label_from_widget(first, appearances[i]);
        if (!first)
            first = GTK_RADIO_BUTTON(choice);
        gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(choice), i == (guint)panels->appearance);
        g_signal_connect(choice, "toggled", G_CALLBACK(changed_appearance), panels);
        gtk_box_pack_start(GTK_BOX(choices), choice, FALSE, FALSE, 0);
    }
    GtkWidget *heading = section(content, "<b>Embedded icons</b>");
    gtk_widget_set_margin_top(heading, 8);
    const char *labels[] = {"Show EXE icons", "Show AppImage icons"};
    for (guint i = 0; i < G_N_ELEMENTS(labels); i++) {
        GtkWidget *choice = gtk_check_button_new_with_label(labels[i]);
        gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(choice), panels->icons[i]);
        g_object_set_data(G_OBJECT(choice), "choice", GUINT_TO_POINTER(i));
        g_signal_connect(choice, "toggled", G_CALLBACK(changed_icons), panels);
        gtk_box_pack_start(GTK_BOX(content), choice, FALSE, FALSE, 0);
    }
    gtk_widget_show_all(panels->interface);
}

void drill_gtk_show_syntax(DrillGtkPanels *panels) {
    if (panels->syntax) {
        gtk_window_present(GTK_WINDOW(panels->syntax));
        return;
    }
    GtkWidget *content = create_dialog(panels, &panels->syntax, "Search syntax");
    gtk_window_set_default_size(GTK_WINDOW(panels->syntax), 520, 560);
    GtkWidget *scroll = gtk_scrolled_window_new(NULL, NULL);
    gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scroll), GTK_POLICY_NEVER, GTK_POLICY_AUTOMATIC);
    gtk_box_pack_start(GTK_BOX(content), scroll, TRUE, TRUE, 0);
    GtkWidget *body = gtk_box_new(GTK_ORIENTATION_VERTICAL, 16);
    gtk_container_set_border_width(GTK_CONTAINER(body), 16);
    gtk_container_add(GTK_CONTAINER(scroll), body);
    section(body, "Files searches file and folder names. An empty Apps search lists applications.");
    section(body, "Use a lowercase prefix at the start of the query. Without a prefix, an asterisk "
                  "selects wildcard search. Otherwise Drill searches for words.");
    section(body, "<b>Words</b>\nEvery word must occur somewhere in the name, in any order. "
                  "Matching ignores case and accents. Dots, question marks and quotes are literal.\n"
                  "<tt>project notes</tt>");
    section(body, "<b>Fuzzy words</b>\nEach query word must resemble a word in the name. "
                  "Use this for approximate spellings. Matching ignores case and accents.\n"
                  "<tt>fuzzy:projecx notes</tt>");
    section(body, "<b>Wildcards</b>\nMatch the whole name. An asterisk (*) matches any number "
                  "of characters, a question mark (?) matches one, [0-9] matches a digit, "
                  "and {jpg,png} offers alternatives. Matching ignores case and accents. "
                  "Use a backslash to escape a wildcard.\n"
                  "<tt>*.md\nglob:page[0-9]?.pdf\nglob:literal\\*.txt</tt>");
    section(body, "<b>Regular expressions</b>\nA Rust regex can match anywhere in the name. "
                  "Use ^ for the start and $ for the end. Matching ignores case by default "
                  "and preserves accents. Add (?-i) for case-sensitive matching.\n"
                  "<tt>regex:^IMG_[0-9]{4}\\.jpg$</tt>");
    section(body, "Invalid patterns show an error. Globs and regexes accept up to 4,096 bytes. "
                  "Glob groups can nest up to eight levels.");
    GtkWidget *more = gtk_expander_new("More pattern syntax");
    gtk_box_pack_start(GTK_BOX(body), more, FALSE, FALSE, 0);
    GtkWidget *references = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8);
    gtk_container_add(GTK_CONTAINER(more), references);
    section(references, "In a glob, [!0-9] matches one character other than a digit. "
                        "&lt;[0-9]:4&gt; matches exactly four digits. The $ wildcard is a lazy version of *.\n"
                        "<a href=\"https://github.com/olson-sean-k/wax/blob/v0.7.0/README.md#patterns\">"
                        "Wax 0.7 glob syntax</a>");
    section(references, "In a regex, use | for alternatives, parentheses for groups, and + to repeat "
                        "the preceding item one or more times. Rust regexes exclude look-around and backreferences.\n"
                        "<a href=\"https://docs.rs/regex/1/regex/#syntax\">Rust regex reference</a>");
    gtk_widget_show_all(panels->syntax);
}
