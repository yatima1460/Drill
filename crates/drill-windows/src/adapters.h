#ifndef DRILL_WINDOWS_ADAPTERS_H
#define DRILL_WINDOWS_ADAPTERS_H

#include <windows.h>
#include <stdbool.h>
#include <stdint.h>

// The callback values also cross the Rust menu adapter boundary.
enum DrillMenuCommand {
    MENU_STOP, MENU_INTERFACE, MENU_SYNTAX, MENU_OPEN, MENU_CLOSE, MENU_UNDO, MENU_REDO,
    MENU_CUT, MENU_COPY, MENU_PASTE, MENU_SELECT_ALL, MENU_FIND, MENU_CONTINUE, MENU_COMMAND_COUNT
};
typedef struct DrillMenu DrillMenu;

DrillMenu *drill_windows_menu_install(HWND owner, void (*callback)(const void *, uint8_t), const void *context);
bool drill_windows_menu_translate(DrillMenu *menu, MSG *message);
void drill_windows_menu_enable(DrillMenu *menu, enum DrillMenuCommand command, bool enabled);
void drill_windows_menu_set_enabled(DrillMenu *menu, bool stop, bool settings);
void drill_windows_menu_set_dark(DrillMenu *menu, bool dark);
void drill_windows_menu_remove(DrillMenu *menu);
bool drill_windows_clipboard_write_text(HWND owner, const WCHAR *text, size_t length);

#endif
