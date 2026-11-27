#include "window_icons.h"
#include <string.h>

enum { ICON_SIZE = 32, CACHE_LIMIT = 512, MAX_LOOKUPS = 8 };

typedef struct {
    uint64_t id;
    GdkPixbuf *pixbuf;
    gboolean wants_embedded, wants_native, exe, appimage;
} CachedIcon;

struct DrillGtkIcons {
    GHashTable *by_id;
    GWeakRef redraw;
    GCancellable *cancel;
    guint active;
    guint refs; // Cache and completions live on the GTK thread.
    uint64_t generation;
    gboolean closed;
};

typedef struct {
    DrillGtkIcons *cache;
    uint64_t id, generation;
} Lookup;

static void free_icon(gpointer data) {
    CachedIcon *icon = data;
    g_clear_object(&icon->pixbuf);
    g_free(icon);
}

DrillGtkIcons *drill_gtk_icon_cache_new(GtkWidget *redraw) {
    DrillGtkIcons *cache = g_new0(DrillGtkIcons, 1);
    // The uint64_t key is stored inside its value.
    cache->by_id = g_hash_table_new_full(g_int64_hash, g_int64_equal, NULL, free_icon);
    g_weak_ref_init(&cache->redraw, redraw);
    cache->cancel = g_cancellable_new();
    cache->refs = 1;
    return cache;
}

void drill_gtk_icon_cache_clear(DrillGtkIcons *cache) {
    cache->generation++;
    g_hash_table_remove_all(cache->by_id);
    g_cancellable_cancel(cache->cancel);
    g_object_unref(cache->cancel);
    cache->cancel = g_cancellable_new();
}

static void cache_unref(DrillGtkIcons *cache) {
    if (--cache->refs)
        return;
    g_hash_table_unref(cache->by_id);
    g_weak_ref_clear(&cache->redraw);
    g_object_unref(cache->cancel);
    g_free(cache);
}

void drill_gtk_icon_cache_free(DrillGtkIcons *cache) {
    cache->closed = TRUE;
    g_cancellable_cancel(cache->cancel);
    cache_unref(cache);
}

GDesktopAppInfo *drill_gtk_registered_app(const char *desktop_id, const char *path) {
    if (!desktop_id || !*desktop_id || strchr(desktop_id, '/'))
        return NULL;
    GDesktopAppInfo *app = g_desktop_app_info_new(desktop_id);
    if (app && (!g_app_info_should_show(G_APP_INFO(app)) ||
                g_strcmp0(g_desktop_app_info_get_filename(app), path) != 0))
        g_clear_object(&app);
    return app;
}

// GIO can return file-backed custom artwork or thumbnails. Pass GTK only
// themed names, including the themed parts of emblems on files and folders.
static GIcon *safe_themed_icon(GIcon *icon, unsigned depth) {
    if (!icon || depth > 2)
        return NULL;
    if (G_IS_THEMED_ICON(icon)) {
        const char *const *names = g_themed_icon_get_names(G_THEMED_ICON(icon));
        for (; *names; names++) {
            if (!**names || strchr(*names, '/'))
                return NULL;
        }
        return g_object_ref(icon);
    }
    if (!G_IS_EMBLEMED_ICON(icon))
        return NULL;
    GEmblemedIcon *decorated = G_EMBLEMED_ICON(icon);
    g_autoptr(GIcon) base = safe_themed_icon(g_emblemed_icon_get_icon(decorated), depth + 1);
    if (!base)
        return NULL;
    GIcon *result = g_emblemed_icon_new(base, NULL);
    for (GList *it = g_emblemed_icon_get_emblems(decorated); it; it = it->next) {
        GEmblem *emblem = it->data;
        g_autoptr(GIcon) badge = safe_themed_icon(g_emblem_get_icon(emblem), depth + 1);
        if (badge) {
            g_autoptr(GEmblem) safe = g_emblem_new(badge);
            g_emblemed_icon_add_emblem(G_EMBLEMED_ICON(result), safe);
        }
    }
    return result;
}

static GdkPixbuf *load_icon(GIcon *icon) {
    g_autoptr(GIcon) safe = safe_themed_icon(icon, 0);
    GtkIconTheme *theme = gtk_icon_theme_get_default();
    if (!safe || !theme)
        return NULL;
    g_autoptr(GtkIconInfo) info = gtk_icon_theme_lookup_by_gicon(theme, safe, ICON_SIZE,
                                                                GTK_ICON_LOOKUP_FORCE_SIZE);
    return info ? gtk_icon_info_load_icon(info, NULL) : NULL;
}

static GdkPixbuf *rgba_pixbuf(const void *pixels) {
    g_autoptr(GBytes) bytes = g_bytes_new(pixels, ICON_SIZE * ICON_SIZE * 4);
    return gdk_pixbuf_new_from_bytes(bytes, GDK_COLORSPACE_RGB, TRUE, 8,
                                     ICON_SIZE, ICON_SIZE, ICON_SIZE * 4);
}

static void rectangle(guint32 pixels[ICON_SIZE][ICON_SIZE], int x, int y,
                      int width, int height, guint32 rgba) {
    for (int row = y; row < y + height; row++)
        for (int col = x; col < x + width; col++)
            pixels[row][col] = GUINT32_TO_BE(rgba);
}

typedef enum { GLYPH_FILE, GLYPH_FOLDER, GLYPH_APPLICATION } Glyph;

static GdkPixbuf *generic_glyph(Glyph glyph) {
    guint32 pixels[ICON_SIZE][ICON_SIZE] = {0};
    if (glyph == GLYPH_APPLICATION) {
        rectangle(pixels, 2, 5, 28, 22, 0x566574ff);
        rectangle(pixels, 4, 11, 24, 14, 0xd9dfe3ff);
        rectangle(pixels, 23, 7, 4, 2, 0xe3ebf1ff);
    } else if (glyph == GLYPH_FOLDER) {
        rectangle(pixels, 3, 6, 11, 6, 0xb18533ff);
        rectangle(pixels, 3, 10, 26, 16, 0xb18533ff);
        rectangle(pixels, 4, 12, 24, 13, 0xe7ba60ff);
    } else {
        rectangle(pixels, 6, 3, 20, 26, 0x74818bff);
        rectangle(pixels, 7, 4, 18, 24, 0xd9dfe3ff);
        rectangle(pixels, 10, 12, 12, 2, 0x8d989fff);
        rectangle(pixels, 10, 17, 9, 2, 0x8d989fff);
    }
    return rgba_pixbuf(pixels);
}

static GdkPixbuf *type_icon(const DrillRow *row) {
    Glyph glyph = row->app_bundle ? GLYPH_APPLICATION : (row->directory ? GLYPH_FOLDER : GLYPH_FILE);
    if (glyph == GLYPH_FILE) {
        // Type fallback takes no bytes from the search result.
        g_autofree char *type = g_content_type_guess(row->path, NULL, 0, NULL);
        if (type) {
            g_autoptr(GIcon) icon = g_content_type_get_icon(type);
            GdkPixbuf *result = load_icon(icon);
            if (result)
                return result;
        }
    }
    static const char *const names[] = {
        [GLYPH_FILE] = "text-x-generic", [GLYPH_FOLDER] = "folder",
        [GLYPH_APPLICATION] = "application-x-executable"
    };
    g_autoptr(GIcon) generic = g_themed_icon_new(names[glyph]);
    GdkPixbuf *result = load_icon(generic);
    return result ? result : generic_glyph(glyph);
}

static void finish_lookup(Lookup *lookup, GIcon *native) {
    DrillGtkIcons *cache = lookup->cache;
    cache->active--;
    if (!cache->closed && native && cache->generation == lookup->generation) {
        // GTK can announce a theme change while resolving the artwork, which
        // invalidates the cache. Reacquire the entry after GTK returns.
        g_autoptr(GdkPixbuf) pixels = load_icon(native);
        if (pixels && !cache->closed && cache->generation == lookup->generation) {
            CachedIcon *icon = g_hash_table_lookup(cache->by_id, &lookup->id);
            if (icon) {
                g_clear_object(&icon->pixbuf);
                icon->pixbuf = g_steal_pointer(&pixels);
            }
        }
    }
    if (!cache->closed) {
        // Also retry visible rows that previously found all slots occupied.
        g_autoptr(GtkWidget) redraw = g_weak_ref_get(&cache->redraw);
        if (redraw)
            gtk_widget_queue_draw(redraw);
    }
    cache_unref(cache);
    g_free(lookup);
}

static void file_info_ready(GObject *source, GAsyncResult *result, gpointer data) {
    g_autoptr(GFileInfo) info = g_file_query_info_finish(G_FILE(source), result, NULL);
    finish_lookup(data, info ? g_file_info_get_icon(info) : NULL);
}

static void app_icon_worker(GTask *task, gpointer source G_GNUC_UNUSED, gpointer task_data,
                            GCancellable *cancel) {
    char **identity = task_data;
    GIcon *icon = NULL;
    if (!g_cancellable_is_cancelled(cancel)) {
        g_autoptr(GDesktopAppInfo) app = drill_gtk_registered_app(identity[0], identity[1]);
        if (app && g_app_info_get_icon(G_APP_INFO(app)))
            icon = g_object_ref(g_app_info_get_icon(G_APP_INFO(app)));
    }
    g_task_return_pointer(task, icon, icon ? g_object_unref : NULL);
}

static void app_icon_ready(GObject *source G_GNUC_UNUSED, GAsyncResult *result, gpointer data) {
    g_autoptr(GIcon) icon = g_task_propagate_pointer(G_TASK(result), NULL);
    finish_lookup(data, icon);
}

static void request_native(DrillGtkIcons *cache, CachedIcon *icon, const DrillRow *row) {
    if (!icon->wants_native || cache->active == MAX_LOOKUPS)
        return;
    icon->wants_native = FALSE;
    cache->active++;
    cache->refs++;
    Lookup *lookup = g_new(Lookup, 1);
    *lookup = (Lookup){cache, icon->id, cache->generation};
    if (row->registered_app && row->desktop_id) {
        g_autoptr(GTask) task = g_task_new(NULL, cache->cancel, app_icon_ready, lookup);
        char **identity = g_new0(char *, 3);
        identity[0] = g_strdup(row->desktop_id);
        identity[1] = g_strdup(row->path);
        g_task_set_task_data(task, identity, (GDestroyNotify)g_strfreev);
        g_task_run_in_thread(task, app_icon_worker);
    } else {
        g_autoptr(GFile) file = g_file_new_for_path(row->path);
        g_file_query_info_async(file, G_FILE_ATTRIBUTE_STANDARD_ICON, G_FILE_QUERY_INFO_NONE,
                                G_PRIORITY_DEFAULT, cache->cancel, file_info_ready, lookup);
    }
}

static gboolean executable_suffix(const char *suffix) {
    return suffix && (g_ascii_strcasecmp(suffix, ".exe") == 0 ||
                      g_ascii_strcasecmp(suffix, ".appimage") == 0);
}

GdkPixbuf *drill_gtk_icon_get(DrillGtkIcons *cache, DrillModel *model, uint64_t id,
                              const DrillRow *row, gboolean exe, gboolean appimage) {
    CachedIcon *icon = g_hash_table_lookup(cache->by_id, &id);
    gboolean needs_type = FALSE;
    if (!icon) {
        if (g_hash_table_size(cache->by_id) >= CACHE_LIMIT)
            drill_gtk_icon_cache_clear(cache);
        icon = g_new0(CachedIcon, 1);
        icon->id = id;
        icon->exe = exe;
        icon->appimage = appimage;
        const char *suffix = strrchr(row->path, '.');
        gboolean executable = executable_suffix(suffix);
        // Bundle artwork comes from the sandbox. A plain .app file uses its type.
        icon->wants_native = !executable && (!suffix || g_ascii_strcasecmp(suffix, ".app") != 0);
        icon->wants_embedded = row->app_bundle || (executable && !row->directory);
        needs_type = TRUE;
        g_hash_table_insert(cache->by_id, &icon->id, icon);
    } else if (icon->exe != exe || icon->appimage != appimage) {
        if (!row->directory && executable_suffix(strrchr(row->path, '.'))) {
            needs_type = TRUE;
            icon->wants_embedded = TRUE;
        }
        icon->exe = exe;
        icon->appimage = appimage;
    }
    request_native(cache, icon, row);
    if (needs_type) {
        uint64_t generation = cache->generation;
        cache->refs++;
        GdkPixbuf *pixels = type_icon(row);
        // Theme signals can synchronously clear this entry or close its window.
        icon = (!cache->closed && generation == cache->generation)
            ? g_hash_table_lookup(cache->by_id, &id) : NULL;
        cache_unref(cache);
        if (!icon)
            return pixels;
        g_clear_object(&icon->pixbuf);
        icon->pixbuf = pixels;
    }
    if (icon->wants_embedded) {
        // All model borrows (including the filename above) have ended.
        uint8_t rgba[ICON_SIZE * ICON_SIZE * 4];
        int state = drill_embedded_icon(model, id, exe, appimage, rgba);
        icon->wants_embedded = state == 0;
        if (state == 1) {
            g_clear_object(&icon->pixbuf);
            icon->pixbuf = rgba_pixbuf(rgba);
        }
    }
    return icon->pixbuf ? g_object_ref(icon->pixbuf) : NULL;
}
