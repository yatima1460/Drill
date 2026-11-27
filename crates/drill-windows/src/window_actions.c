// Built with menu.c and clipboard.c in the Windows SDK adapter.
#include "window_actions.h"
#include "window_preferences.c"
#include "window_shell.c"

typedef struct DrillWinIcons DrillWinIcons;
DrillWinIcons *drill_win_icons_create(HWND owner, HWND table, DrillModel *model);
void drill_win_icons_destroy(DrillWinIcons *icons);
void drill_win_icons_reset(DrillWinIcons *icons);
int drill_win_icons_get(DrillWinIcons *icons, uint64_t id, bool exe, bool appimage);

HWND drill_panel_show(HWND owner, HWND previous, bool settings, unsigned appearance,
                      bool exe, bool appimage, bool dark);
void drill_panel_apply(HWND panel, bool dark);

struct DrillWinActions {
    HWND owner, settings, help;
    DrillModel *model;
    DrillMenu *menu;
    DrillWinIcons *icons;
    DWORD prefs[WIN_PREF_COUNT];
    bool dark;
};

static void win_menu_command(const void *context, uint8_t command) {
    DrillWinActions *actions = (DrillWinActions *)context;
    if (command == STOP_MENU) {
        drill_stop(actions->model);
        return;
    }
    bool settings = command == SETTINGS_MENU;
    HWND *panel = settings ? &actions->settings : &actions->help;
    *panel = drill_panel_show(actions->owner, *panel, settings, actions->prefs[WIN_APPEARANCE],
                             actions->prefs[WIN_EXE_ICONS] != 0, actions->prefs[WIN_APPIMAGE_ICONS] != 0,
                             actions->dark);
    if (!*panel) win_action_error(actions->owner, E_FAIL, L"Could not open the window");
}

DrillWinActions *drill_win_actions_create(HWND owner, DrillModel *model, HWND table) {
    DrillWinActions *actions = calloc(1, sizeof(*actions));
    if (!actions) return NULL;
    actions->owner = owner;
    actions->model = model;
    win_load_prefs(actions->prefs);
    actions->menu = drill_windows_menu_install(owner, win_menu_command, actions);
    if (!actions->menu) {
        free(actions);
        return NULL;
    }
    actions->icons = drill_win_icons_create(owner, table, model);
    drill_win_refresh_theme(actions);
    return actions;
}

void drill_win_actions_destroy(DrillWinActions *actions) {
    if (!actions) return;
    if (actions->settings) DestroyWindow(actions->settings);
    if (actions->help) DestroyWindow(actions->help);
    drill_windows_menu_remove(actions->menu);
    if (actions->icons) drill_win_icons_destroy(actions->icons);
    free(actions);
}

void drill_win_actions_update(DrillWinActions *actions, bool can_stop) {
    if (actions) drill_windows_menu_set_enabled(actions->menu, can_stop, true);
}

bool drill_win_dark(const DrillWinActions *actions) {
    return actions && actions->dark;
}

void drill_win_refresh_theme(DrillWinActions *actions) {
    if (!actions) return;
    bool dark = win_resolve_dark(actions->prefs[WIN_APPEARANCE]);
    if (dark == actions->dark) return;
    actions->dark = dark;
    drill_windows_menu_set_dark(actions->menu, dark);
    drill_panel_apply(actions->settings, dark);
    drill_panel_apply(actions->help, dark);
}

void drill_win_set_preference(DrillWinActions *actions, unsigned key, unsigned value) {
    if (!actions || key >= WIN_PREF_COUNT || value > (key == WIN_APPEARANCE ? 2u : 1u) ||
        actions->prefs[key] == value) return;
    actions->prefs[key] = value;
    LSTATUS saved = win_write_pref(key, value);
    if (key == WIN_APPEARANCE) drill_win_refresh_theme(actions);
    else drill_win_reset_icons(actions);
    SendMessageW(actions->owner, DRILL_WM_PREFERENCES, 0, 0);
    if (saved != ERROR_SUCCESS) win_action_error(actions->owner, HRESULT_FROM_WIN32(saved), L"Could not save the preference");
}

void drill_win_panel_closed(DrillWinActions *actions, HWND panel) {
    if (!actions) return;
    if (actions->help == panel) actions->help = NULL;
    if (actions->settings == panel) actions->settings = NULL;
}

bool drill_win_dialog_message(DrillWinActions *actions, MSG *message) {
    if (!actions) return false;
    HWND root = GetAncestor(message->hwnd, GA_ROOT);
    return root && (root == actions->settings || root == actions->help) && IsDialogMessageW(root, message);
}

int drill_win_icon(DrillWinActions *actions, uint64_t id) {
    if (!actions || !actions->icons) return I_IMAGENONE;
    return drill_win_icons_get(actions->icons, id, actions->prefs[WIN_EXE_ICONS] != 0,
                               actions->prefs[WIN_APPIMAGE_ICONS] != 0);
}

void drill_win_reset_icons(DrillWinActions *actions) {
    if (actions && actions->icons) drill_win_icons_reset(actions->icons);
}

static WCHAR *win_copy_cell(const char *utf8) {
    int length = MultiByteToWideChar(CP_UTF8, 0, utf8, -1, NULL, 0);
    WCHAR *copy = length > 0 ? malloc((size_t)length * sizeof(*copy)) : NULL;
    if (copy && !MultiByteToWideChar(CP_UTF8, 0, utf8, -1, copy, length)) {
        free(copy);
        return NULL;
    }
    return copy;
}

static void win_copy_text(HWND owner, const WCHAR *text) {
    if (!drill_windows_clipboard_write_text(owner, text, wcslen(text) + 1)) {
        win_action_error(owner, HRESULT_FROM_WIN32(ERROR_CLIPBOARD_NOT_OPEN), L"Could not copy to the clipboard");
    }
}

static void win_default_action(DrillWinActions *actions, uint64_t id, bool copy) {
    DrillRow row;
    if (!actions || !drill_row(actions->model, id, &row)) return;
    HWND owner = actions->owner;
    WCHAR *path = _wcsdup((const WCHAR *)row.path);
    if (!path) {
        win_action_error(owner, E_OUTOFMEMORY, L"Could not read the selected result");
    } else if (copy) {
        win_copy_text(owner, path);
    } else {
        win_action_error(owner, win_open_item(owner, path), L"Could not open the selected result");
    }
    free(path);
}

void drill_win_open(DrillWinActions *actions, uint64_t id) {
    win_default_action(actions, id, false);
}

void drill_win_copy_path(DrillWinActions *actions, uint64_t id) {
    win_default_action(actions, id, true);
}

enum { RESULT_OPEN = 1, RESULT_OPEN_WITH, RESULT_REVEAL, RESULT_TERMINAL,
       RESULT_COPY_PATH, RESULT_COPY_DATE, RESULT_COPY_SIZE };

void drill_win_context(DrillWinActions *actions, uint64_t id, POINT screen, bool apps) {
    DrillRow row;
    if (!actions || !drill_row(actions->model, id, &row)) return;
    // The popup, system dialogs and Shell can dispatch window messages. Own the
    // target and displayed values even if the query changes while the menu is open.
    HWND owner = actions->owner;
    WCHAR *path = _wcsdup((const WCHAR *)row.path);
    WCHAR *date = win_copy_cell(row.cells[3]), *size = win_copy_cell(row.cells[2]);
    bool directory = row.directory;
    HMENU menu = CreatePopupMenu();
    if (!menu || !path || !date || !size) {
        win_action_error(owner, E_OUTOFMEMORY, L"Could not open the result menu");
    } else {
        AppendMenuW(menu, MF_STRING, RESULT_OPEN, apps ? L"&Launch" : L"&Open");
        AppendMenuW(menu, MF_STRING, RESULT_OPEN_WITH, L"Open &With\x2026");
        AppendMenuW(menu, MF_STRING, RESULT_REVEAL, L"Show in File &Explorer");
        AppendMenuW(menu, MF_STRING, RESULT_TERMINAL, L"Open &Terminal Here");
        AppendMenuW(menu, MF_SEPARATOR, 0, NULL);
        AppendMenuW(menu, MF_STRING, RESULT_COPY_PATH, L"Copy Full &Path");
        AppendMenuW(menu, MF_STRING, RESULT_COPY_DATE, L"Copy &Date");
        AppendMenuW(menu, MF_STRING, RESULT_COPY_SIZE, L"Copy &Size");
        SetMenuDefaultItem(menu, RESULT_OPEN, FALSE);
        HBITMAP images[2] = {NULL, NULL};
        win_context_images(owner, menu, images, RESULT_REVEAL, RESULT_TERMINAL);
        UINT command = TrackPopupMenuEx(menu, TPM_RETURNCMD | TPM_NONOTIFY | TPM_RIGHTBUTTON,
                                        screen.x, screen.y, owner, NULL);
        DestroyMenu(menu);
        menu = NULL;
        for (unsigned i = 0; i < ARRAYSIZE(images); ++i) {
            if (images[i]) DeleteObject(images[i]);
        }
        if (IsWindow(owner)) {
            switch (command) {
            case RESULT_OPEN:
                win_action_error(owner, win_open_item(owner, path), L"Could not open the selected result");
                break;
            case RESULT_OPEN_WITH: {
                OPENASINFO info = {path, NULL, OAIF_EXEC};
                win_action_error(owner, SHOpenWithDialog(owner, &info), L"Could not open with the selected application");
                break;
            }
            case RESULT_REVEAL:
                win_action_error(owner, win_show_in_explorer(path), L"Could not show the selected result in File Explorer");
                break;
            case RESULT_TERMINAL:
                win_action_error(owner, win_terminal_here(path, directory), L"Could not open a terminal here");
                break;
            case RESULT_COPY_PATH: win_copy_text(owner, path); break;
            case RESULT_COPY_DATE: win_copy_text(owner, date); break;
            case RESULT_COPY_SIZE: win_copy_text(owner, size); break;
            }
        }
    }
    if (menu) DestroyMenu(menu);
    free(path);
    free(date);
    free(size);
}
