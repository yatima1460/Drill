#include <gtk/gtk.h>

gboolean drill_gtk_init(void) {
    GMainContext *context = g_main_context_default();
    if (!g_main_context_acquire(context)) {
        return FALSE;
    }

    char name[] = "drill";
    char *arguments[] = {name, NULL};
    char **argv = arguments;
    int argc = 1;
    // Keep the default context owned by the UI thread for GTK's lifetime.
    if (gtk_init_check(&argc, &argv)) {
        return TRUE;
    }
    g_main_context_release(context);
    return FALSE;
}

// The caller owns the returned reference, if any.
GdkPixbuf *drill_gtk_load_icon(const char *name, int size) {
    GtkIconTheme *theme = gtk_icon_theme_get_default();
    return theme ? gtk_icon_theme_load_icon(theme, name, size, 0, NULL) : NULL;
}

GdkPixbuf *drill_gtk_load_file_icon(const char *path, int size, gboolean filename_only) {
    char *guessed_type = NULL;
    GFileInfo *info = NULL;
    const char *content_type;
    if (filename_only) {
        guessed_type = g_content_type_guess(path, NULL, 0, NULL);
        content_type = guessed_type;
    } else {
        GFile *file = g_file_new_for_path(path);
        info = g_file_query_info(file, G_FILE_ATTRIBUTE_STANDARD_CONTENT_TYPE,
                                 G_FILE_QUERY_INFO_NONE, NULL, NULL);
        g_object_unref(file);
        content_type = info ? g_file_info_get_content_type(info) : NULL;
    }

    GdkPixbuf *pixels = NULL;
    if (content_type) {
        GIcon *icon = g_content_type_get_icon(content_type);
        if (icon && G_IS_THEMED_ICON(icon)) {
            const char *const *names = g_themed_icon_get_names(G_THEMED_ICON(icon));
            for (; *names && !pixels; ++names) {
                pixels = drill_gtk_load_icon(*names, size);
            }
        }
        g_clear_object(&icon);
    }
    g_clear_object(&info);
    g_free(guessed_type);
    return pixels;
}

typedef struct {
    int width;
    int height;
    int stride;
    int channels;
    size_t len;
    const unsigned char *data;
} DrillGtkPixels;

// Pixel storage is borrowed until the caller releases the pixbuf.
DrillGtkPixels drill_gtk_pixbuf_pixels(GdkPixbuf *pixbuf) {
    return (DrillGtkPixels) {
        .width = gdk_pixbuf_get_width(pixbuf),
        .height = gdk_pixbuf_get_height(pixbuf),
        .stride = gdk_pixbuf_get_rowstride(pixbuf),
        .channels = gdk_pixbuf_get_n_channels(pixbuf),
        .len = gdk_pixbuf_get_byte_length(pixbuf),
        .data = gdk_pixbuf_read_pixels(pixbuf),
    };
}

void drill_gtk_release_pixbuf(GdkPixbuf *pixbuf) {
    g_object_unref(pixbuf);
}

// Returns an owned error message on failure. Cancellation is success.
char *drill_gtk_open_with(const char *path) {
    GFile *file = g_file_new_for_path(path);
    GtkWidget *dialog = gtk_app_chooser_dialog_new(NULL, GTK_DIALOG_MODAL, file);
    g_object_ref(dialog);
    char *message = NULL;
    gint response = gtk_dialog_run(GTK_DIALOG(dialog));
    if (response == GTK_RESPONSE_OK || response == GTK_RESPONSE_ACCEPT) {
        GAppInfo *app = gtk_app_chooser_get_app_info(GTK_APP_CHOOSER(dialog));
        if (app) {
            GList files = {.data = file};
            GError *error = NULL;
            if (!g_app_info_launch(app, &files, NULL, &error)) {
                message = g_strdup(error ? error->message : "Could not open the file");
            }
            g_clear_error(&error);
            g_object_unref(app);
        } else {
            message = g_strdup("No application was selected");
        }
    }

    gtk_widget_hide(dialog);
    gtk_widget_destroy(dialog);
    g_object_unref(dialog);
    g_object_unref(file);
    return message;
}

void drill_gtk_free_error(char *message) {
    g_free(message);
}
