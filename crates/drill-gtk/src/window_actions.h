#ifndef DRILL_WINDOW_ACTIONS_H
#define DRILL_WINDOW_ACTIONS_H

#include <gtk/gtk.h>
#include "DrillDesktop.h"

typedef struct DrillGtkActions DrillGtkActions;

DrillGtkActions *drill_gtk_actions_new(GtkWindow *window, GtkWidget *search_entry,
                                      GtkWidget *tree_view, DrillModel *model);
void drill_gtk_actions_free(DrillGtkActions *actions);
GtkWidget *drill_gtk_actions_menubar(DrillGtkActions *actions);
void drill_gtk_actions_update(DrillGtkActions *actions, const DrillState *state);
void drill_gtk_actions_select(DrillGtkActions *actions, uint64_t id);
void drill_gtk_actions_open(DrillGtkActions *actions, const DrillRow *row);
void drill_gtk_actions_popup(DrillGtkActions *actions, const DrillRow *row, GdkEvent *event);
/* Caller owns the returned reference, if any. */
GdkPixbuf *drill_gtk_row_icon(DrillGtkActions *actions, DrillModel *model,
                             uint64_t id, const DrillRow *row);

#endif
