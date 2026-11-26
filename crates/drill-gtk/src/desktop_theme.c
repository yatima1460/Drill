#include <gio/gio.h>

#define PORTAL "org.freedesktop.portal.Desktop"
#define PORTAL_PATH "/org/freedesktop/portal/desktop"
#define SETTINGS "org.freedesktop.portal.Settings"
#define APPEARANCE "org.freedesktop.appearance"
#define COLOR_SCHEME "color-scheme"

typedef enum {
    THEME_UNAVAILABLE,
    THEME_LIGHT,
    THEME_DARK,
} Theme;

typedef void (*PublishTheme)(gint theme, gpointer data);

typedef struct {
    GMainContext *context;
    GCancellable *stop;
    PublishTheme publish;
    gpointer data;
    gchar *owner;
    guint64 generation;
    gint pending;
} ThemeObserver;

typedef struct {
    ThemeObserver *observer;
    guint64 generation;
} ThemeRead;

GCancellable *drill_desktop_theme_new_stop(void) {
    return g_cancellable_new();
}

void drill_desktop_theme_stop(GCancellable *stop) {
    g_cancellable_cancel(stop);
}

void drill_desktop_theme_free_stop(GCancellable *stop) {
    g_object_unref(stop);
}

static Theme color_scheme(GVariant *value) {
    if (!value || !g_variant_is_of_type(value, G_VARIANT_TYPE_UINT32)) {
        return THEME_UNAVAILABLE;
    }
    // Like the existing UI, use light for a valid portal value other than dark.
    return g_variant_get_uint32(value) == 1 ? THEME_DARK : THEME_LIGHT;
}

static Theme read_all(GVariant *reply) {
    if (!reply || !g_variant_is_of_type(reply, G_VARIANT_TYPE("(a{sa{sv}})"))) {
        return THEME_UNAVAILABLE;
    }
    g_autoptr(GVariant) namespaces = g_variant_get_child_value(reply, 0);
    g_autoptr(GVariant) settings = g_variant_lookup_value(namespaces, APPEARANCE,
                                                         G_VARIANT_TYPE_VARDICT);
    g_autoptr(GVariant) value = settings
        ? g_variant_lookup_value(settings, COLOR_SCHEME, G_VARIANT_TYPE_UINT32)
        : NULL;
    return color_scheme(value);
}

static void publish(ThemeObserver *observer, Theme theme) {
    if (!g_cancellable_is_cancelled(observer->stop)) {
        observer->publish(theme, observer->data);
    }
}

static void setting_changed(GDBusConnection *bus G_GNUC_UNUSED, const gchar *sender,
                            const gchar *path G_GNUC_UNUSED, const gchar *interface G_GNUC_UNUSED,
                            const gchar *signal G_GNUC_UNUSED, GVariant *params, gpointer data) {
    ThemeObserver *observer = data;
    if (g_strcmp0(sender, observer->owner) != 0
        || !g_variant_is_of_type(params, G_VARIANT_TYPE("(ssv)"))) {
        return;
    }
    const gchar *name_space;
    const gchar *key;
    g_autoptr(GVariant) value = NULL;
    g_variant_get(params, "(&s&sv)", &name_space, &key, &value);
    if (g_str_equal(name_space, APPEARANCE) && g_str_equal(key, COLOR_SCHEME)) {
        observer->generation++;
        publish(observer, color_scheme(value));
    }
}

static void finished(gpointer data) {
    ThemeObserver *observer = data;
    // GIO may release a watcher from a different thread. Retain the context
    // across the decrement so it remains valid after the worker sees zero.
    GMainContext *context = g_main_context_ref(observer->context);
    g_atomic_int_add(&observer->pending, -1);
    g_main_context_wakeup(context);
    g_main_context_unref(context);
}

static void read_finished(GObject *source, GAsyncResult *result, gpointer data) {
    g_autofree ThemeRead *request = data;
    ThemeObserver *observer = request->observer;
    g_autoptr(GVariant) reply = g_dbus_connection_call_finish(G_DBUS_CONNECTION(source),
                                                            result, NULL);
    // A reply from a previous owner or before a live signal cannot replace it.
    if (request->generation == observer->generation) {
        publish(observer, read_all(reply));
    }
    finished(observer);
}

static void name_appeared(GDBusConnection *bus, const gchar *name G_GNUC_UNUSED,
                          const gchar *owner, gpointer data) {
    ThemeObserver *observer = data;
    if (g_cancellable_is_cancelled(observer->stop)) {
        return;
    }
    g_free(observer->owner);
    observer->owner = g_strdup(owner);
    ThemeRead *request = g_new(ThemeRead, 1);
    *request = (ThemeRead) {observer, ++observer->generation};
    g_atomic_int_inc(&observer->pending);

    const gchar *namespaces[] = {APPEARANCE, NULL};
    g_dbus_connection_call(bus, owner, PORTAL_PATH, SETTINGS, "ReadAll",
                           g_variant_new("(^as)", namespaces),
                           G_VARIANT_TYPE("(a{sa{sv}})"), G_DBUS_CALL_FLAGS_NONE, 2000,
                           observer->stop, read_finished, request);
}

static void name_vanished(GDBusConnection *bus G_GNUC_UNUSED,
                          const gchar *name G_GNUC_UNUSED, gpointer data) {
    ThemeObserver *observer = data;
    g_clear_pointer(&observer->owner, g_free);
    observer->generation++;
    publish(observer, THEME_UNAVAILABLE);
}

static gboolean stop_loop(GCancellable *stop G_GNUC_UNUSED, gpointer loop) {
    g_main_loop_quit(loop);
    return G_SOURCE_REMOVE;
}

void drill_desktop_theme_observe(GCancellable *stop, PublishTheme callback, gpointer data) {
    g_autoptr(GMainContext) context = g_main_context_new();
    g_main_context_push_thread_default(context);
    g_autofree gchar *address = g_dbus_address_get_for_bus_sync(G_BUS_TYPE_SESSION, stop, NULL);
    // Keep a private connection so a lost session bus cannot terminate Drill.
    g_autoptr(GDBusConnection) bus = address ? g_dbus_connection_new_for_address_sync(
        address, G_DBUS_CONNECTION_FLAGS_AUTHENTICATION_CLIENT
            | G_DBUS_CONNECTION_FLAGS_MESSAGE_BUS_CONNECTION, NULL, stop, NULL) : NULL;
    if (bus) {
        g_dbus_connection_set_exit_on_close(bus, FALSE);
        ThemeObserver observer = {.context = context, .stop = stop, .publish = callback,
                                  .data = data, .pending = 2};
        guint signal = g_dbus_connection_signal_subscribe(
            bus, PORTAL, SETTINGS, "SettingChanged", PORTAL_PATH, APPEARANCE,
            G_DBUS_SIGNAL_FLAGS_NONE, setting_changed, &observer, finished);
        guint watch = g_bus_watch_name_on_connection(bus, PORTAL, G_BUS_NAME_WATCHER_FLAGS_AUTO_START,
            name_appeared, name_vanished, &observer, finished);

        g_autoptr(GMainLoop) loop = g_main_loop_new(context, FALSE);
        g_autoptr(GSource) cancel_source = g_cancellable_source_new(stop);
        g_source_set_callback(cancel_source, G_SOURCE_FUNC(stop_loop), loop, NULL);
        g_source_attach(cancel_source, context);
        g_main_loop_run(loop);

        g_bus_unwatch_name(watch);
        g_dbus_connection_signal_unsubscribe(bus, signal);
        g_dbus_connection_close_sync(bus, NULL, NULL);
        // Process the pending read completions and both subscription destroy
        // callbacks before the worker returns its borrowed Rust callback.
        while (g_atomic_int_get(&observer.pending) != 0) {
            g_main_context_iteration(context, TRUE);
        }
        g_free(observer.owner);
    }
    g_main_context_pop_thread_default(context);
}
