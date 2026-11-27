#ifndef DRILL_WINDOW_ACTIONS_H
#define DRILL_WINDOW_ACTIONS_H
#include <windows.h>
#include "../../drill-desktop/include/DrillDesktop.h"

#define DRILL_WM_PREFERENCES  (WM_APP + 41)
#define DRILL_WM_SET_PREF     (WM_APP + 42)
#define DRILL_WM_PANEL_CLOSED (WM_APP + 43)

typedef struct DrillWinActions DrillWinActions;
DrillWinActions *drill_win_actions_create(HWND owner, DrillModel *model, HWND table);
void drill_win_actions_destroy(DrillWinActions *actions);
void drill_win_actions_update(DrillWinActions *actions, bool can_stop);
void drill_win_open(DrillWinActions *actions, uint64_t id);
void drill_win_copy_path(DrillWinActions *actions, uint64_t id);
void drill_win_context(DrillWinActions *actions, uint64_t id, POINT screen, bool apps);
int drill_win_icon(DrillWinActions *actions, uint64_t id);
void drill_win_reset_icons(DrillWinActions *actions);
bool drill_win_dark(const DrillWinActions *actions);
void drill_win_refresh_theme(DrillWinActions *actions);
void drill_win_set_preference(DrillWinActions *actions, unsigned key, unsigned value);
void drill_win_panel_closed(DrillWinActions *actions, HWND panel);
bool drill_win_dialog_message(DrillWinActions *actions, MSG *message);
#endif
