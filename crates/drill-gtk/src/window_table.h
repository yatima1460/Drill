#ifndef DRILL_GTK_WINDOW_TABLE_H
#define DRILL_GTK_WINDOW_TABLE_H
#include "window_actions.h"

typedef struct DrillGtkTable DrillGtkTable;
DrillGtkTable *drill_gtk_table_new(GtkTreeView *view, GtkWidget *entry,
                                  DrillModel *model, DrillGtkActions *actions);
void drill_gtk_table_update(DrillGtkTable *table, const DrillState *state);
void drill_gtk_table_move(DrillGtkTable *table, int offset);
void drill_gtk_table_open_selected(DrillGtkTable *table);
#endif
