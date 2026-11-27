#ifndef DRILL_GTK_WINDOW_ICONS_H
#define DRILL_GTK_WINDOW_ICONS_H

#include "DrillDesktop.h"
#include <gtk/gtk.h>
#include <gio/gdesktopappinfo.h>

typedef struct DrillGtkIcons DrillGtkIcons;
DrillGtkIcons *drill_gtk_icon_cache_new(GtkWidget *redraw);
void drill_gtk_icon_cache_clear(DrillGtkIcons *icons);
void drill_gtk_icon_cache_free(DrillGtkIcons *icons);
// Both functions return owned references, or NULL when unavailable.
GDesktopAppInfo *drill_gtk_registered_app(const char *desktop_id, const char *path);
GdkPixbuf *drill_gtk_icon_get(DrillGtkIcons *cache, DrillModel *model, uint64_t id,
                              const DrillRow *row, gboolean exe, gboolean appimage);

#endif
