// The mock runs inside the Rust test's private dbus-run-session subprocess.
#include <gio/gio.h>

#define PORTAL "org.freedesktop.portal.Desktop"
#define PORTAL_PATH "/org/freedesktop/portal/desktop"
#define SETTINGS "org.freedesktop.portal.Settings"
#define APPEARANCE "org.freedesktop.appearance"
#define COLOR_SCHEME "color-scheme"

typedef struct {
    GMainContext *context;
    GDBusConnection *bus;
    guint registration;
    gboolean hold_read;
    GDBusMethodInvocation *pending_read;
} ThemeFixture;

static void return_settings(GDBusMethodInvocation *invocation) {
    g_dbus_method_invocation_return_value(invocation, g_variant_new_parsed(
        "({'" APPEARANCE "': {'" COLOR_SCHEME "': <%u>}},)", 1u));
}

static void read_all(GDBusConnection *bus G_GNUC_UNUSED, const gchar *sender G_GNUC_UNUSED,
                     const gchar *path G_GNUC_UNUSED, const gchar *interface G_GNUC_UNUSED,
                     const gchar *method G_GNUC_UNUSED, GVariant *params,
                     GDBusMethodInvocation *invocation, gpointer data) {
    g_auto(GStrv) namespaces = NULL;
    g_variant_get(params, "(^as)", &namespaces);
    g_assert_cmpstr(namespaces[0], ==, APPEARANCE);
    g_assert_null(namespaces[1]);
    ThemeFixture *fixture = data;
    if (fixture->hold_read) {
        g_assert_null(fixture->pending_read);
        fixture->pending_read = invocation;
    } else {
        return_settings(invocation);
    }
}

ThemeFixture *drill_theme_fixture_new(void) {
    static const GDBusInterfaceVTable vtable = {.method_call = read_all};
    g_autoptr(GError) error = NULL;
    g_autoptr(GDBusNodeInfo) info = g_dbus_node_info_new_for_xml(
        "<node><interface name='" SETTINGS "'><method name='ReadAll'>"
        "<arg direction='in' type='as'/><arg direction='out' type='a{sa{sv}}'/>"
        "</method></interface></node>", &error);
    g_assert_no_error(error);

    ThemeFixture *fixture = g_new0(ThemeFixture, 1);
    fixture->context = g_main_context_new();
    g_main_context_push_thread_default(fixture->context);
    fixture->bus = g_bus_get_sync(G_BUS_TYPE_SESSION, NULL, &error);
    g_assert_no_error(error);
    fixture->registration = g_dbus_connection_register_object(
        fixture->bus, PORTAL_PATH, info->interfaces[0], &vtable, fixture, NULL, &error);
    g_assert_no_error(error);
    return fixture;
}

void drill_theme_fixture_set_owner(ThemeFixture *fixture, gint acquire) {
    g_autoptr(GError) error = NULL;
    g_autoptr(GVariant) reply = g_dbus_connection_call_sync(
        fixture->bus, "org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus",
        acquire ? "RequestName" : "ReleaseName",
        acquire ? g_variant_new("(su)", PORTAL, 4u) : g_variant_new("(s)", PORTAL),
        G_VARIANT_TYPE("(u)"), G_DBUS_CALL_FLAGS_NONE, 2000, NULL, &error);
    g_assert_no_error(error);
    guint32 result;
    g_variant_get(reply, "(u)", &result);
    g_assert_cmpuint(result, ==, 1);
}

void drill_theme_fixture_emit(ThemeFixture *fixture, const gchar *name_space, const gchar *key,
                              gint value) {
    g_autoptr(GError) error = NULL;
    g_dbus_connection_emit_signal(fixture->bus, NULL, PORTAL_PATH, SETTINGS, "SettingChanged",
        g_variant_new("(ssv)", name_space, key,
            value < 0 ? g_variant_new_string("invalid") : g_variant_new_uint32((guint32) value)),
        &error);
    g_assert_no_error(error);
}

void drill_theme_fixture_hold_read(ThemeFixture *fixture) {
    fixture->hold_read = TRUE;
}

gboolean drill_theme_fixture_dispatch(ThemeFixture *fixture) {
    g_main_context_iteration(fixture->context, FALSE);
    return fixture->pending_read != NULL;
}

void drill_theme_fixture_reply(ThemeFixture *fixture) {
    g_assert_nonnull(fixture->pending_read);
    return_settings(g_steal_pointer(&fixture->pending_read));
}

void drill_theme_fixture_free(ThemeFixture *fixture) {
    g_dbus_connection_unregister_object(fixture->bus, fixture->registration);
    g_clear_object(&fixture->pending_read);
    g_object_unref(fixture->bus);
    g_main_context_pop_thread_default(fixture->context);
    g_main_context_unref(fixture->context);
    g_free(fixture);
}
