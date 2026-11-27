// The menu, accelerators and window subclass belong to the UI thread.
#define WIN32_LEAN_AND_MEAN
#include "adapters.h"
#include <commctrl.h>
#include <stdlib.h>
#include "menu_appearance.c"

enum { FIRST_DRILL_COMMAND = 0x4001, DRILL_SUBCLASS = 1 };

enum { FILE_POPUP, EDIT_POPUP, SEARCH_POPUP, SETTINGS_POPUP, HELP_POPUP };

static const struct {
    UINT popup;
    enum DrillMenuCommand command;
    const WCHAR *label;
    BYTE modifiers;
    WORD key;
} items[] = {
    { FILE_POPUP, MENU_OPEN, L"&Open Selection\tCtrl+O", FCONTROL, 'O' },
    { FILE_POPUP, MENU_CLOSE, L"&Close Window\tCtrl+W", FCONTROL, 'W' },
    { EDIT_POPUP, MENU_UNDO, L"&Undo\tCtrl+Z", FCONTROL, 'Z' },
    { EDIT_POPUP, MENU_REDO, L"&Redo\tCtrl+Y", FCONTROL, 'Y' },
    { EDIT_POPUP, MENU_COMMAND_COUNT, NULL, 0, 0 },
    { EDIT_POPUP, MENU_CUT, L"Cu&t\tCtrl+X", FCONTROL, 'X' },
    { EDIT_POPUP, MENU_COPY, L"&Copy\tCtrl+C", FCONTROL, 'C' },
    { EDIT_POPUP, MENU_PASTE, L"&Paste\tCtrl+V", FCONTROL, 'V' },
    { EDIT_POPUP, MENU_SELECT_ALL, L"Select &All\tCtrl+A", FCONTROL, 'A' },
    { SEARCH_POPUP, MENU_FIND, L"&Find\tCtrl+F", FCONTROL, 'F' },
    { SEARCH_POPUP, MENU_STOP, L"&Stop", 0, 0 },
    { SEARCH_POPUP, MENU_CONTINUE, L"&Continue", 0, 0 },
    { SETTINGS_POPUP, MENU_INTERFACE, L"&Interface\x2026\tCtrl+,", FCONTROL, VK_OEM_COMMA },
    { HELP_POPUP, MENU_SYNTAX, L"&Syntax\tF1", 0, VK_F1 },
};

struct DrillMenu {
    unsigned references;
    HWND window;
    HMENU bar, previous, popups[ARRAYSIZE(drill_menu_titles)];
    HACCEL accelerators;
    void (*dispatch)(const void *, uint8_t);
    const void *context;
    bool settings;
    DrillMenuAppearance appearance;
};

static const WCHAR menu_property[] = L"software.drill.NativeMenu";
static LRESULT CALLBACK drill_menu_proc(HWND, UINT, WPARAM, LPARAM, UINT_PTR, DWORD_PTR);

// The Rust handle and any in-flight window messages keep this allocation live.
// SetMenu and menu callbacks can synchronously dispatch another window message.
static void release_menu(DrillMenu *menu) {
    if (--menu->references == 0) {
        if (menu->bar) {
            DestroyMenu(menu->bar);
        }
        if (menu->accelerators) DestroyAcceleratorTable(menu->accelerators);
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
    if (command >= MENU_COMMAND_COUNT || !menu->dispatch) {
        return false;
    }
    UINT state = GetMenuState(menu->bar, FIRST_DRILL_COMMAND + command, MF_BYCOMMAND);
    if (!(state & (MF_DISABLED | MF_GRAYED)) && (command != MENU_INTERFACE || menu->settings)) {
        menu->dispatch(menu->context, (uint8_t)command);
        // The callback can synchronously detach the menu.
    }
    return true;
}

static LRESULT process_menu_message(DrillMenu *menu, HWND window, UINT message, WPARAM wp, LPARAM lp) {
    if (message == WM_DESTROY || message == WM_NCDESTROY) {
        detach_menu(menu);
    } else if (GetMenu(window) == menu->bar) {
        if (message == WM_MENUCOMMAND) {
            for (unsigned i = 0; i < ARRAYSIZE(menu->popups); ++i) {
                if ((HMENU)lp == menu->popups[i]) {
                    UINT id = GetMenuItemID(menu->popups[i], (int)wp);
                    if (dispatch_menu(menu, id - FIRST_DRILL_COMMAND)) return 0;
                    break;
                }
            }
        }
        // User32 sends a command by ID for accelerators and accessibility clients.
        if (message == WM_COMMAND && lp == 0 && HIWORD(wp) <= 1 &&
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

static bool build_menu(DrillMenu *menu) {
    MENUINFO info = {0};
    info.cbSize = sizeof(info);
    info.fMask = MIM_STYLE;
    info.dwStyle = MNS_NOTIFYBYPOS;
    for (unsigned i = 0; i < ARRAYSIZE(menu->popups); ++i) {
        HMENU popup = CreatePopupMenu();
        if (!popup) return false;
        if (!SetMenuInfo(popup, &info) ||
            !AppendMenuW(menu->bar, MF_POPUP, (UINT_PTR)popup, drill_menu_titles[i].pszWText)) {
            DestroyMenu(popup);
            return false;
        }
        menu->popups[i] = popup; // From here the parent menu owns it.
    }
    ACCEL keys[ARRAYSIZE(items)];
    int count = 0;
    for (unsigned i = 0; i < ARRAYSIZE(items); ++i) {
        WORD id = (WORD)(FIRST_DRILL_COMMAND + items[i].command);
        UINT flags = items[i].label ? MF_STRING : MF_SEPARATOR;
        if (items[i].command == MENU_STOP || items[i].command == MENU_CONTINUE) flags |= MF_GRAYED;
        if (!AppendMenuW(menu->popups[items[i].popup], flags, id, items[i].label)) return false;
        if (items[i].key) {
            keys[count].cmd = id;
            keys[count].fVirt = FVIRTKEY | FNOINVERT | items[i].modifiers;
            keys[count++].key = items[i].key;
        }
    }
    menu->accelerators = CreateAcceleratorTableW(keys, count);
    return menu->accelerators != NULL;
}

DrillMenu *drill_windows_menu_install(HWND window, void (*callback)(const void *, uint8_t),
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
    if (menu->bar && build_menu(menu) &&
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

bool drill_windows_menu_translate(DrillMenu *menu, MSG *message) {
    if (!menu || !menu->window || GetAncestor(message->hwnd, GA_ROOT) != menu->window ||
        (message->message != WM_KEYDOWN && message->message != WM_SYSKEYDOWN)) return false;
    // Keep a held Open Selection accelerator from launching the same result repeatedly.
    if (message->wParam == 'O' && (message->lParam & (1L << 30)) &&
        (GetKeyState(VK_CONTROL) & 0x8000) && !((GetKeyState(VK_MENU) | GetKeyState(VK_SHIFT)) & 0x8000))
        return true;
    return TranslateAcceleratorW(menu->window, menu->accelerators, message) != 0;
}

void drill_windows_menu_enable(DrillMenu *menu, enum DrillMenuCommand command, bool enabled) {
    if (menu && menu->window)
        EnableMenuItem(menu->bar, FIRST_DRILL_COMMAND + command, MF_BYCOMMAND | (enabled ? MF_ENABLED : MF_GRAYED));
}

void drill_windows_menu_set_enabled(DrillMenu *menu, bool stop, bool settings) {
    drill_windows_menu_enable(menu, MENU_STOP, stop);
    if (menu->window && menu->settings != settings &&
        EnableMenuItem(menu->bar, SETTINGS_POPUP, MF_BYPOSITION | (settings ? MF_ENABLED : MF_GRAYED)) != -1) {
        menu->settings = settings;
        DrawMenuBar(menu->window);
    }
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
