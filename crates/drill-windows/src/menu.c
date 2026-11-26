// Drill's three window menu commands. Keep the menu and subclass on the UI thread.
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <commctrl.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include "menu_appearance.c"

enum { STOP_MENU, SETTINGS_MENU, HELP_MENU, MENU_COUNT };
enum { FIRST_DRILL_COMMAND = 0x4001, DRILL_SUBCLASS = 1 };

typedef struct {
    unsigned references;
    HWND window;
    HMENU bar, previous, popups[MENU_COUNT];
    void (*dispatch)(const void *, uint8_t);
    const void *context;
    bool stop, settings;
    DrillMenuAppearance appearance;
} DrillMenu;

static const WCHAR menu_property[] = L"software.drill.NativeMenu";
static LRESULT CALLBACK drill_menu_proc(HWND, UINT, WPARAM, LPARAM, UINT_PTR, DWORD_PTR);

// The Rust handle and any in-flight window messages keep this allocation live.
// SetMenu and menu callbacks can synchronously dispatch another window message.
static void release_menu(DrillMenu *menu) {
    if (--menu->references == 0) {
        if (menu->bar) {
            DestroyMenu(menu->bar);
        }
        free(menu);
    }
}

static void detach_menu(DrillMenu *menu) {
    HWND window = menu->window;
    menu->window = NULL;
    RemovePropW(window, menu_property);
    RemoveWindowSubclass(window, drill_menu_proc, DRILL_SUBCLASS);
    if (GetMenu(window) == menu->bar && !SetMenu(window, menu->previous)) {
        // The window still owns the menu and will release it on destruction.
        menu->bar = NULL;
    }
}

static bool dispatch_menu(DrillMenu *menu, unsigned command) {
    if (command >= MENU_COUNT || !menu->dispatch) {
        return false;
    }
    if ((command != STOP_MENU || menu->stop) && (command != SETTINGS_MENU || menu->settings)) {
        menu->dispatch(menu->context, (uint8_t)command);
        // The callback can synchronously detach the menu.
    }
    return true;
}

static LRESULT process_menu_message(DrillMenu *menu, HWND window, UINT message, WPARAM wp, LPARAM lp) {
    if (message == WM_DESTROY || message == WM_NCDESTROY) {
        detach_menu(menu);
    } else if (GetMenu(window) == menu->bar) {
        if (message == WM_MENUCOMMAND && wp == 0) {
            for (unsigned i = 0; i < MENU_COUNT; ++i) {
                if ((HMENU)lp == menu->popups[i] && dispatch_menu(menu, i)) {
                    return 0;
                }
            }
        }
        // Also accept a menu invocation by its public command ID, e.g. automation.
        if (message == WM_COMMAND && lp == 0 && HIWORD(wp) == 0 &&
            dispatch_menu(menu, (unsigned)LOWORD(wp) - FIRST_DRILL_COMMAND)) {
            return 0;
        }
        if (message == WM_THEMECHANGED || message == WM_SETTINGCHANGE) {
            drill_menu_set_appearance(&menu->appearance, window, menu->bar, menu->appearance.requested_dark);
        }
        if (message == WM_MENUCHAR && menu->appearance.active_dark && (HMENU)lp == menu->bar) {
            LRESULT mnemonic = drill_menu_character(menu->bar, LOWORD(wp));
            if (mnemonic) {
                return mnemonic;
            }
        }
        if (drill_menu_draw_item(window, message, wp, lp)) {
            return TRUE;
        }
    }
    return DefSubclassProc(window, message, wp, lp);
}

static LRESULT CALLBACK drill_menu_proc(HWND window, UINT message, WPARAM wp, LPARAM lp,
                                        UINT_PTR subclass, DWORD_PTR data) {
    (void)subclass;
    switch (message) {
        case WM_DESTROY: case WM_NCDESTROY: case WM_MENUCOMMAND: case WM_COMMAND:
        case WM_THEMECHANGED: case WM_SETTINGCHANGE: case WM_DRAWITEM: case WM_MEASUREITEM: case WM_MENUCHAR:
            break;
        default:
            return DefSubclassProc(window, message, wp, lp);
    }

    DrillMenu *menu = GetPropW(window, menu_property);
    if (!menu || (DWORD_PTR)menu != data) {
        return DefSubclassProc(window, message, wp, lp);
    }
    ++menu->references;
    LRESULT result = process_menu_message(menu, window, message, wp, lp);
    release_menu(menu);
    return result;
}

static bool add_command(DrillMenu *menu, unsigned index, const WCHAR *label) {
    HMENU popup = CreatePopupMenu();
    MENUINFO info = {0};
    info.cbSize = sizeof(info);
    info.fMask = MIM_STYLE;
    info.dwStyle = MNS_NOTIFYBYPOS;
    UINT flags = MF_STRING | (index == STOP_MENU ? MF_GRAYED : MF_ENABLED);
    if (!popup) {
        return false;
    }
    if (!SetMenuInfo(popup, &info) || !AppendMenuW(popup, flags, FIRST_DRILL_COMMAND + index, label) ||
        !AppendMenuW(menu->bar, MF_POPUP, (UINT_PTR)popup, drill_menu_titles[index].pszWText)) {
        DestroyMenu(popup);
        return false;
    }
    menu->popups[index] = popup; // The attached parent now owns this submenu.
    return true;
}

void *drill_windows_menu_install(HWND window, void (*callback)(const void *, uint8_t),
                                 const void *context) {
    if (GetWindowThreadProcessId(window, NULL) != GetCurrentThreadId() ||
        GetPropW(window, menu_property)) {
        return NULL;
    }
    DrillMenu *menu = calloc(1, sizeof(*menu));
    if (!menu) {
        return NULL;
    }
    menu->references = 1;
    menu->bar = CreateMenu();
    menu->previous = GetMenu(window);
    menu->settings = true;
    menu->context = context;
    if (menu->bar && add_command(menu, STOP_MENU, L"Stop") &&
        add_command(menu, SETTINGS_MENU, L"Interface\x2026") &&
        add_command(menu, HELP_MENU, L"Syntax") &&
        SetWindowSubclass(window, drill_menu_proc, DRILL_SUBCLASS, (DWORD_PTR)menu)) {
        menu->window = window;
        if (SetPropW(window, menu_property, menu) && SetMenu(window, menu->bar) && menu->window) {
            menu->dispatch = callback;
            return menu;
        }
        if (menu->window) {
            detach_menu(menu);
        }
    }
    release_menu(menu);
    return NULL;
}

static void set_command_enabled(HMENU parent, unsigned position, bool enabled, bool *old) {
    if (*old != enabled &&
        EnableMenuItem(parent, position, MF_BYPOSITION | (enabled ? MF_ENABLED : MF_GRAYED)) != -1) {
        *old = enabled;
    }
}

void drill_windows_menu_set_enabled(DrillMenu *menu, bool stop, bool settings) {
    if (!menu->window || (menu->stop == stop && menu->settings == settings)) {
        return;
    }
    set_command_enabled(menu->popups[STOP_MENU], 0, stop, &menu->stop);
    set_command_enabled(menu->bar, SETTINGS_MENU, settings, &menu->settings);
    DrawMenuBar(menu->window);
}

void drill_windows_menu_set_dark(DrillMenu *menu, bool dark) {
    if (menu->window && dark != menu->appearance.requested_dark) {
        drill_menu_set_appearance(&menu->appearance, menu->window, menu->bar, dark);
    }
}

void drill_windows_menu_remove(DrillMenu *menu) {
    menu->dispatch = NULL;
    if (menu->window) {
        detach_menu(menu);
    }
    release_menu(menu);
}
