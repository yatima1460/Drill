#include <gio/gdesktopappinfo.h>

struct DrillDesktopApp {
    const char *id;
    const char *path;
    const char *display_name;
    const char *const *keywords;
    const char *const *icon_names;
};

typedef void (*DrillAppVisitor)(void *context, const struct DrillDesktopApp *app);
typedef void (*DrillLaunchError)(void *context, const char *message);

enum DrillLaunchStatus {
    DRILL_APP_LAUNCHED = 0,
    DRILL_APP_UNAVAILABLE = 1,
    DRILL_APP_LAUNCH_FAILED = 2,
};

void drill_visit_desktop_apps(void *context, DrillAppVisitor visit)
{
    GList *apps = g_app_info_get_all();
    for (GList *item = apps; item != NULL; item = item->next) {
        GAppInfo *app = item->data;
        if (!G_IS_DESKTOP_APP_INFO(app) || !g_app_info_should_show(app))
            continue;

        GDesktopAppInfo *desktop = G_DESKTOP_APP_INFO(app);
        struct DrillDesktopApp entry = {
            .id = g_app_info_get_id(app),
            .path = g_desktop_app_info_get_filename(desktop),
            .display_name = g_app_info_get_display_name(app),
            .keywords = g_desktop_app_info_get_keywords(desktop),
            .icon_names = NULL,
        };
        if (entry.id == NULL || entry.path == NULL || entry.display_name == NULL)
            continue;

        GIcon *icon = g_app_info_get_icon(app);
        if (icon != NULL && G_IS_THEMED_ICON(icon))
            entry.icon_names = g_themed_icon_get_names(G_THEMED_ICON(icon));
        visit(context, &entry);
    }
    g_list_free_full(apps, g_object_unref);
}

int drill_launch_desktop_app(const char *id, const char *path,
                             void *context, DrillLaunchError report_error)
{
    GDesktopAppInfo *desktop = g_desktop_app_info_new(id);
    if (desktop == NULL)
        return DRILL_APP_UNAVAILABLE;

    GAppInfo *app = G_APP_INFO(desktop);
    if (!g_app_info_should_show(app) ||
        g_strcmp0(g_desktop_app_info_get_filename(desktop), path) != 0) {
        g_object_unref(desktop);
        return DRILL_APP_UNAVAILABLE;
    }

    GError *error = NULL;
    gboolean launched = g_app_info_launch(app, NULL, NULL, &error);
    if (!launched && error != NULL)
        report_error(context, error->message);
    g_clear_error(&error);
    g_object_unref(desktop);
    return launched ? DRILL_APP_LAUNCHED : DRILL_APP_LAUNCH_FAILED;
}
