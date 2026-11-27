#ifndef DRILL_GTK_WINDOW_PANELS_H
#define DRILL_GTK_WINDOW_PANELS_H

#include <gtk/gtk.h>

typedef struct DrillGtkPanels DrillGtkPanels;

DrillGtkPanels *drill_gtk_panels_new(GtkWindow *parent, void (*icons_changed)(void *), void *context);
void drill_gtk_panels_free(DrillGtkPanels *panels);
void drill_gtk_panels_update(DrillGtkPanels *panels);
void drill_gtk_show_interface(DrillGtkPanels *panels);
void drill_gtk_show_syntax(DrillGtkPanels *panels);
gboolean drill_gtk_exe_icons(const DrillGtkPanels *panels);
gboolean drill_gtk_appimage_icons(const DrillGtkPanels *panels);

#endif
