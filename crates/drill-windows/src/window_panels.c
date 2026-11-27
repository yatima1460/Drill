// Modeless Win32 dialogs. Dialog units follow the system's UI font and DPI.
#include "window_actions.h"
#include <dwmapi.h>
#include <shellapi.h>
#include <uxtheme.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>

enum {
    PANEL_AUTO = 6101, PANEL_LIGHT, PANEL_DARK, PANEL_EXE, PANEL_APPIMAGE,
    PANEL_SYNTAX, PANEL_DETAILS, PANEL_GLOB_LINK, PANEL_REGEX_LINK,
    PANEL_APPEARANCE_LABEL, PANEL_ICONS_LABEL
};

static const WCHAR panel_syntax[] =
    L"Files searches file and folder names. An empty Apps search lists applications.\r\n\r\n"
    L"Use a lowercase prefix at the start of the query. Without a prefix, an asterisk "
    L"selects wildcard search. Otherwise Drill searches for words.\r\n\r\n"
    L"Words\r\nEvery word must occur somewhere in the name, in any order. Matching ignores "
    L"case and accents. Dots, question marks and quotes are literal.\r\n"
    L"project notes\r\n\r\n"
    L"Fuzzy words\r\nEach query word must resemble a word in the name. Use this for "
    L"approximate spellings. Matching ignores case and accents.\r\nfuzzy:projecx notes\r\n\r\n"
    L"Wildcards\r\nMatch the whole name. An asterisk (*) matches any number of characters, "
    L"a question mark (?) matches one, [0-9] matches a digit, and {jpg,png} offers "
    L"alternatives. Matching ignores case and accents. Use a backslash to escape a wildcard.\r\n"
    L"*.md\r\nglob:page[0-9]?.pdf\r\nglob:literal\\*.txt\r\n\r\n"
    L"Regular expressions\r\nA Rust regex can match anywhere in the name. Use ^ for the "
    L"start and $ for the end. Matching ignores case by default and preserves accents. "
    L"Add (?-i) for case-sensitive matching.\r\nregex:^IMG_[0-9]{4}\\.jpg$\r\n\r\n"
    L"Invalid patterns show an error. Globs and regexes accept up to 4,096 bytes. "
    L"Glob groups can nest up to eight levels.";

static const WCHAR panel_more[] =
    L"\r\n\r\nMore pattern syntax\r\nIn a glob, [!0-9] matches one character other than "
    L"a digit. <[0-9]:4> matches exactly four digits. The $ wildcard is a lazy version of *.\r\n\r\n"
    L"In a regex, use | for alternatives, parentheses for groups, and + to repeat the preceding "
    L"item one or more times. Rust regexes exclude look-around and backreferences.";

typedef struct {
    bool settings, exe, appimage, dark, created;
    unsigned appearance;
} DrillPanelInit;

static HWND panel_control(HWND dialog, int id, const WCHAR *class_name, const WCHAR *text, DWORD style) {
    HWND control = CreateWindowExW(0, class_name, text, WS_CHILD | WS_VISIBLE | style,
        0, 0, 1, 1, dialog, (HMENU)(INT_PTR)id, GetModuleHandleW(NULL), NULL);
    if (control) SendMessageW(control, WM_SETFONT, SendMessageW(dialog, WM_GETFONT, 0, 0), FALSE);
    return control;
}

static bool panel_preferences(HWND dialog, const DrillPanelInit *initial) {
    if (!panel_control(dialog, PANEL_APPEARANCE_LABEL, L"STATIC", L"Appearance", 0) ||
        !panel_control(dialog, PANEL_AUTO, L"BUTTON", L"Auto", WS_GROUP | WS_TABSTOP | BS_AUTORADIOBUTTON) ||
        !panel_control(dialog, PANEL_LIGHT, L"BUTTON", L"Light", BS_AUTORADIOBUTTON) ||
        !panel_control(dialog, PANEL_DARK, L"BUTTON", L"Dark", BS_AUTORADIOBUTTON) ||
        !panel_control(dialog, PANEL_ICONS_LABEL, L"STATIC", L"Embedded icons", WS_GROUP) ||
        !panel_control(dialog, PANEL_EXE, L"BUTTON", L"Show EXE icons", WS_TABSTOP | BS_AUTOCHECKBOX) ||
        !panel_control(dialog, PANEL_APPIMAGE, L"BUTTON", L"Show AppImage icons", WS_TABSTOP | BS_AUTOCHECKBOX)) {
        return false;
    }
    CheckRadioButton(dialog, PANEL_AUTO, PANEL_DARK, PANEL_AUTO + (int)initial->appearance);
    CheckDlgButton(dialog, PANEL_EXE, initial->exe ? BST_CHECKED : BST_UNCHECKED);
    CheckDlgButton(dialog, PANEL_APPIMAGE, initial->appimage ? BST_CHECKED : BST_UNCHECKED);
    return true;
}

static bool panel_help(HWND dialog) {
    return panel_control(dialog, PANEL_SYNTAX, L"EDIT", panel_syntax,
               WS_TABSTOP | WS_VSCROLL | ES_MULTILINE | ES_READONLY | ES_AUTOVSCROLL) &&
        panel_control(dialog, PANEL_DETAILS, L"BUTTON", L"More pattern syntax", WS_TABSTOP | BS_AUTOCHECKBOX) &&
        panel_control(dialog, PANEL_GLOB_LINK, L"BUTTON", L"Wax 0.7 glob syntax", WS_TABSTOP) &&
        panel_control(dialog, PANEL_REGEX_LINK, L"BUTTON", L"Rust regex reference", WS_TABSTOP);
}

static void panel_move(HWND dialog, int id, int x, int y, int width, int height) {
    RECT rect = { x, y, x + width, y + height };
    MapDialogRect(dialog, &rect);
    MoveWindow(GetDlgItem(dialog, id), rect.left, rect.top,
               rect.right - rect.left, rect.bottom - rect.top, TRUE);
}

static void panel_layout(HWND dialog) {
    RECT client;
    RECT units = { 0, 0, 4, 8 };
    GetClientRect(dialog, &client);
    if (!MapDialogRect(dialog, &units) || !units.right || !units.bottom) return;
    int width = MulDiv(client.right, 4, units.right);
    int height = MulDiv(client.bottom, 8, units.bottom);
    panel_move(dialog, IDCANCEL, width - 58, height - 22, 50, 14);
    if (GetDlgItem(dialog, PANEL_AUTO)) {
        panel_move(dialog, PANEL_APPEARANCE_LABEL, 10, 9, 180, 11);
        panel_move(dialog, PANEL_AUTO, 12, 23, 48, 12);
        panel_move(dialog, PANEL_LIGHT, 66, 23, 48, 12);
        panel_move(dialog, PANEL_DARK, 120, 23, 48, 12);
        panel_move(dialog, PANEL_ICONS_LABEL, 10, 45, 180, 11);
        panel_move(dialog, PANEL_EXE, 12, 60, 190, 12);
        panel_move(dialog, PANEL_APPIMAGE, 12, 76, 190, 12);
    } else if (GetDlgItem(dialog, PANEL_SYNTAX)) {
        bool more = IsDlgButtonChecked(dialog, PANEL_DETAILS) == BST_CHECKED;
        int bottom = height - (more ? 46 : 26);
        panel_move(dialog, PANEL_SYNTAX, 8, 8, width - 16, bottom - 12);
        panel_move(dialog, PANEL_DETAILS, 8, bottom + 3, 135, 14);
        panel_move(dialog, PANEL_GLOB_LINK, 8, height - 22, 82, 14);
        panel_move(dialog, PANEL_REGEX_LINK, 94, height - 22, 86, 14);
        ShowWindow(GetDlgItem(dialog, PANEL_GLOB_LINK), more ? SW_SHOWNA : SW_HIDE);
        ShowWindow(GetDlgItem(dialog, PANEL_REGEX_LINK), more ? SW_SHOWNA : SW_HIDE);
    }
}

void drill_panel_apply(HWND dialog, bool dark) {
    if (!dialog) return;
    SetWindowLongPtrW(dialog, DWLP_USER, dark);
    BOOL title_dark = dark;
    DwmSetWindowAttribute(dialog, DWMWA_USE_IMMERSIVE_DARK_MODE, &title_dark, sizeof(title_dark));
    // Classic check/radio controls honor WM_CTLCOLORSTATIC when the app supplies colors.
    for (int i = PANEL_AUTO; i <= PANEL_DETAILS; ++i) {
        HWND child = GetDlgItem(dialog, i);
        if (child && i != PANEL_SYNTAX) {
            SetWindowTheme(child, dark ? L"" : NULL, dark ? L"" : NULL);
        }
    }
    RedrawWindow(dialog, NULL, NULL, RDW_ERASE | RDW_INVALIDATE | RDW_ALLCHILDREN | RDW_FRAME);
}

static void panel_toggle_details(HWND dialog) {
    bool more = IsDlgButtonChecked(dialog, PANEL_DETAILS) == BST_CHECKED;
    WCHAR full[ARRAYSIZE(panel_syntax) + ARRAYSIZE(panel_more) - 1];
    memcpy(full, panel_syntax, sizeof(panel_syntax));
    if (more) memcpy(full + ARRAYSIZE(panel_syntax) - 1, panel_more, sizeof(panel_more));
    HWND edit = GetDlgItem(dialog, PANEL_SYNTAX);
    SetWindowTextW(edit, full);
    panel_layout(dialog);
    SendMessageW(edit, EM_LINESCROLL, 0, more ? SendMessageW(edit, EM_GETLINECOUNT, 0, 0) : 0);
}

static INT_PTR CALLBACK drill_panel_proc(HWND dialog, UINT message, WPARAM wp, LPARAM lp) {
    switch (message) {
    case WM_INITDIALOG: {
        DrillPanelInit *initial = (DrillPanelInit *)lp;
        SetWindowTextW(dialog, initial->settings ? L"Interface" : L"Search syntax");
        bool ready = initial->settings ? panel_preferences(dialog, initial) : panel_help(dialog);
        initial->created = ready && panel_control(dialog, IDCANCEL, L"BUTTON", L"Close", WS_TABSTOP);
        if (initial->created) {
            panel_layout(dialog);
            drill_panel_apply(dialog, initial->dark);
            SetFocus(GetDlgItem(dialog, IDCANCEL));
        }
        return FALSE;
    }
    case WM_SIZE:
        panel_layout(dialog);
        return FALSE;
    case WM_GETMINMAXINFO: {
        if (GetDlgItem(dialog, PANEL_SYNTAX)) {
            RECT minimum = { 0, 0, 252, 150 };
            MapDialogRect(dialog, &minimum);
            MINMAXINFO *info = (MINMAXINFO *)lp;
            info->ptMinTrackSize.x = minimum.right;
            info->ptMinTrackSize.y = minimum.bottom;
            return TRUE;
        }
        break;
    }
    case WM_CTLCOLORDLG:
    case WM_CTLCOLORSTATIC:
    case WM_CTLCOLOREDIT:
        if (GetWindowLongPtrW(dialog, DWLP_USER)) {
            HDC dc = (HDC)wp;
            SetTextColor(dc, RGB(242, 242, 242));
            SetBkColor(dc, RGB(32, 32, 32));
            SetDCBrushColor(dc, RGB(32, 32, 32));
            return (INT_PTR)GetStockObject(DC_BRUSH);
        }
        break;
    case WM_COMMAND: {
        int id = LOWORD(wp);
        if (id == IDCANCEL) {
            DestroyWindow(dialog);
            return TRUE;
        }
        if (HIWORD(wp) != BN_CLICKED) break;
        HWND owner = GetWindow(dialog, GW_OWNER);
        if (id >= PANEL_AUTO && id <= PANEL_DARK) {
            CheckRadioButton(dialog, PANEL_AUTO, PANEL_DARK, id);
            SendMessageW(owner, DRILL_WM_SET_PREF, 0, id - PANEL_AUTO);
        } else if (id == PANEL_EXE || id == PANEL_APPIMAGE) {
            SendMessageW(owner, DRILL_WM_SET_PREF, id == PANEL_EXE ? 1 : 2,
                         IsDlgButtonChecked(dialog, id) == BST_CHECKED);
        } else if (id == PANEL_DETAILS) {
            panel_toggle_details(dialog);
        } else if (id == PANEL_GLOB_LINK || id == PANEL_REGEX_LINK) {
            const WCHAR *url = id == PANEL_GLOB_LINK
                ? L"https://github.com/olson-sean-k/wax/blob/v0.7.0/README.md#patterns"
                : L"https://docs.rs/regex/1/regex/#syntax";
            if ((INT_PTR)ShellExecuteW(dialog, L"open", url, NULL, NULL, SW_SHOWNORMAL) <= 32) {
                MessageBoxW(dialog, L"Could not open the reference in your web browser.",
                            L"Search syntax", MB_OK | MB_ICONERROR);
            }
        } else {
            break;
        }
        return TRUE;
    }
    case WM_CLOSE:
        DestroyWindow(dialog);
        return TRUE;
    case WM_NCDESTROY:
        SendMessageW(GetWindow(dialog, GW_OWNER), DRILL_WM_PANEL_CLOSED, (WPARAM)dialog, 0);
        break;
    }
    return FALSE;
}

HWND drill_panel_show(HWND owner, HWND previous, bool settings, unsigned appearance,
                      bool exe, bool appimage, bool dark) {
    if (previous && IsWindow(previous)) {
        ShowWindow(previous, IsIconic(previous) ? SW_RESTORE : SW_SHOW);
        SetForegroundWindow(previous);
        return previous;
    }
    // Standard dialog template followed by its variable-length WORD fields.
    DECLSPEC_ALIGN(4) struct {
        DLGTEMPLATE dialog;
        WORD menu, window_class, title, font_size;
        WCHAR font[9];
    } layout = { {0}, 0, 0, 0, 9, L"Segoe UI" };
    layout.dialog.style = WS_POPUP | WS_CAPTION | WS_SYSMENU | DS_CENTER | DS_SETFONT |
        (settings ? DS_MODALFRAME : WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX);
    layout.dialog.cx = settings ? 223 : 318;
    layout.dialog.cy = settings ? 124 : 305;
    DrillPanelInit initial = { settings, exe, appimage, dark, false, appearance };
    HWND dialog = CreateDialogIndirectParamW(GetModuleHandleW(NULL), &layout.dialog, owner,
                                             drill_panel_proc, (LPARAM)&initial);
    if (dialog && !initial.created) {
        DestroyWindow(dialog);
        return NULL;
    }
    if (dialog) ShowWindow(dialog, SW_SHOW);
    return dialog;
}
