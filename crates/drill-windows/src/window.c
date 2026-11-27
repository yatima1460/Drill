/* Win32 owns the event loop, edit, combo box, report view, menus and dialogs.
 * The Rust model is called synchronously on this UI thread. */
#include <windowsx.h>
#include <commctrl.h>
#include <oleacc.h>
#include <uxtheme.h>
#include <limits.h>
#include <wchar.h>
#include "adapters.h"
#include "window_accessibility.c"
#include "window_placement.c"

enum { ID_QUERY = 101, ID_MODE, ID_RESULTS, ID_STATUS, ID_STOP, ID_CONTINUE };
typedef struct {
    DrillModel *model;
    DrillWinActions *actions;
    DrillMenu *menu;
    DrillListAccessibility *accessibility;
    DrillPlacement placement;
    HWND hwnd, query_label, query, mode_label, mode, table, status, stop, resume;
    HFONT font;
    HBRUSH background, field;
    COLORREF face_color, text_color, list_color, stripe_color;
    UINT dpi;
    int previous_width, sort_column;
    bool dark, apps, syncing, composing, ascending, poll_again, redo_available;
    uint64_t revision, icon_revision, press_id;
} DrillWindow;

static int px(const DrillWindow *ui, int logical) {
    return MulDiv(logical, (int)ui->dpi, 96);
}

static void update_window(DrillWindow *);
#include "window_table.c"

static void update_window(DrillWindow *ui) {
    if (ui->syncing || !ui->actions) return;
    DrillState state = drill_tick(ui->model);
    ui->poll_again = state.poll_again;
    bool changed = state.revision != ui->revision;
    bool icons_changed = state.icon_revision != ui->icon_revision;
    if (!changed && !icons_changed) return;
    ui->revision = state.revision;
    ui->icon_revision = state.icon_revision;
    if (changed) {
        // Copy before any Win32 call that could dispatch a nested message.
        WCHAR *status = win_copy_cell(state.status);
        int count = state.count > INT_MAX ? INT_MAX : (int)state.count;
        int index = state.selected_index >= 0 && state.selected_index < count ?
                        (int)state.selected_index : -1;
        ui->syncing = true;
        if (ListView_GetItemCount(ui->table) != count) {
            ListView_SetItemCountEx(ui->table, count, LVSICF_NOINVALIDATEALL | LVSICF_NOSCROLL);
        }
        if (index != selected_index(ui)) {
            show_selection(ui, index);
        }
        ui->syncing = false;
        if (status) {
            SetWindowTextW(ui->status, status);
            free(status);
        }
        EnableWindow(ui->stop, state.can_stop);
        ShowWindow(ui->resume, state.can_continue ? SW_SHOWNA : SW_HIDE);
        drill_windows_menu_enable(ui->menu, MENU_STOP, state.can_stop);
        drill_windows_menu_enable(ui->menu, MENU_CONTINUE, state.can_continue);
    }
    InvalidateRect(ui->table, NULL, FALSE);
}

static int next_window_message(DrillWindow *ui, MSG *message) {
    // Drain one bounded batch between messages. Input and paints get the first
    // opportunity on every pass. GetMessage sleeps on the ordinary timer once
    // the producer's queue is empty.
    while (ui->poll_again && !PeekMessageW(message, NULL, 0, 0, PM_NOREMOVE)) {
        update_window(ui);
    }
    return GetMessageW(message, NULL, 0, 0);
}

static void search_changed(DrillWindow *ui) {
    if (!ui->actions) return;
    int length = GetWindowTextLengthW(ui->query);
    if (length == INT_MAX) return;
    WCHAR *query = calloc((size_t)length + 1, sizeof(*query));
    if (!query) return;
    GetWindowTextW(ui->query, query, length + 1);
    int size = WideCharToMultiByte(CP_UTF8, 0, query, -1, NULL, 0, NULL, NULL);
    char *utf8 = size > 0 ? malloc((size_t)size) : NULL;
    if (utf8) {
        WideCharToMultiByte(CP_UTF8, 0, query, -1, utf8, size, NULL, NULL);
        ui->apps = ComboBox_GetCurSel(ui->mode) == 1;
        drill_query(ui->model, utf8, ui->apps);
        ui->press_id = 0;
        drill_win_reset_icons(ui->actions);
        SendMessageW(ui->query, EM_SETCUEBANNER, TRUE, (LPARAM)(ui->apps ? L"Search apps" : L"Search files"));
        update_window(ui);
        free(utf8);
    }
    free(query);
}

static void apply_colors(DrillWindow *ui) {
    ui->dark = ui->actions && drill_win_dark(ui->actions);
    if (ui->menu) drill_windows_menu_set_dark(ui->menu, ui->dark);
    BOOL dark_title = ui->dark;
    DwmSetWindowAttribute(ui->hwnd, DRILL_DWM_DARK_TITLE, &dark_title, sizeof(dark_title));
    ui->text_color = ui->dark ? RGB(242,242,242) : GetSysColor(COLOR_WINDOWTEXT);
    ui->list_color = ui->dark ? RGB(30,30,30) : GetSysColor(COLOR_WINDOW);
    ui->face_color = ui->dark ? RGB(40,40,40) : GetSysColor(COLOR_BTNFACE);
    HIGHCONTRASTW contrast = {0};
    contrast.cbSize = sizeof(contrast);
    BOOL high = SystemParametersInfoW(SPI_GETHIGHCONTRAST, sizeof(contrast), &contrast, 0) &&
                (contrast.dwFlags & HCF_HIGHCONTRASTON);
    ui->stripe_color = high ? ui->list_color : RGB(
        (GetRValue(ui->list_color) + GetRValue(ui->face_color)) / 2,
        (GetGValue(ui->list_color) + GetGValue(ui->face_color)) / 2,
        (GetBValue(ui->list_color) + GetBValue(ui->face_color)) / 2);
    HBRUSH background = CreateSolidBrush(ui->face_color), field = CreateSolidBrush(ui->list_color);
    if (background) {
        DeleteObject(ui->background);
        ui->background = background;
    }
    if (field) {
        DeleteObject(ui->field);
        ui->field = field;
    }
    ListView_SetTextColor(ui->table, ui->text_color);
    ListView_SetBkColor(ui->table, ui->list_color);
    ListView_SetTextBkColor(ui->table, ui->list_color);
    RedrawWindow(ui->hwnd, NULL, NULL, RDW_INVALIDATE | RDW_ERASE | RDW_ALLCHILDREN);
}

static void apply_font(DrillWindow *ui) {
    NONCLIENTMETRICSW metrics = {0};
    metrics.cbSize = sizeof(metrics);
    if (!SystemParametersInfoForDpi(SPI_GETNONCLIENTMETRICS, sizeof(metrics), &metrics, 0, ui->dpi)) return;
    HFONT next = CreateFontIndirectW(&metrics.lfMessageFont);
    if (!next) return;
    for (HWND control = GetWindow(ui->hwnd, GW_CHILD); control; control = GetWindow(control, GW_HWNDNEXT)) {
        SendMessageW(control, WM_SETFONT, (WPARAM)next, TRUE);
    }
    DeleteObject(ui->font);
    ui->font = next;
}

static void layout_window(DrillWindow *ui) {
    if (!ui->table || !ui->resume) return;
    RECT rect;
    GetClientRect(ui->hwnd, &rect);
    int width = rect.right, height = rect.bottom;
    int gap = px(ui, 8), margin = px(ui, 12), row = px(ui, 26);
    int label = px(ui, 48), mode_label = px(ui, 56), mode = px(ui, 90);
    int mx = width - margin - mode, qx = margin + label;
    int qwidth = max(1, mx - mode_label - 2 * gap - qx);
    int table_y = 2 * margin + row, footer = height - margin - row;
    MoveWindow(ui->query_label, margin, margin, label, row, TRUE);
    MoveWindow(ui->query, qx, margin, qwidth, row, TRUE);
    MoveWindow(ui->mode_label, mx - mode_label - gap, margin, mode_label, row, TRUE);
    MoveWindow(ui->mode, mx, margin, mode, px(ui, 130), TRUE);
    MoveWindow(ui->table, 0, table_y, width, max(1, footer - margin - table_y), TRUE);
    int button = px(ui, 82), stop_x = width - margin - button, resume_x = stop_x - gap - button;
    MoveWindow(ui->status, margin, footer, max(1, resume_x - margin - gap), row, TRUE);
    MoveWindow(ui->resume, resume_x, footer, button, row, TRUE);
    MoveWindow(ui->stop, stop_x, footer, button, row, TRUE);

    // Preserve user widths. Only distribute the change in window width.
    int delta = width - ui->previous_width;
    if (width > 0 && delta) {
        int name = ListView_GetColumnWidth(ui->table, 0), path = ListView_GetColumnWidth(ui->table, 1);
        int minimum = px(ui, 80);
        ListView_SetColumnWidth(ui->table, 0, max(minimum, name + delta / 2));
        ListView_SetColumnWidth(ui->table, 1, max(minimum, path + delta - delta / 2));
        ui->previous_width = width;
    }
}

static bool plain_key(void) {
    return !(GetKeyState(VK_CONTROL) & 0x8000) && !(GetKeyState(VK_MENU) & 0x8000) &&
           !(GetKeyState(VK_SHIFT) & 0x8000);
}

static LRESULT dark_header(DrillWindow *ui, NMCUSTOMDRAW *draw) {
    if (draw->dwDrawStage == CDDS_PREPAINT) {
        FillRect(draw->hdc, &draw->rc, ui->background);
        return CDRF_NOTIFYITEMDRAW;
    }
    if (draw->dwDrawStage != CDDS_ITEMPREPAINT) return CDRF_DODEFAULT;
    int column = (int)draw->dwItemSpec;
    WCHAR title[32] = {0};
    HDITEMW item = {0};
    item.mask = HDI_TEXT | HDI_FORMAT;
    item.pszText = title;
    item.cchTextMax = ARRAYSIZE(title);
    if (!Header_GetItem(draw->hdr.hwndFrom, column, &item)) return CDRF_DODEFAULT;
    RECT area = draw->rc;
    FillRect(draw->hdc, &area, ui->background);
    DrawEdge(draw->hdc, &area, BDR_SUNKENOUTER, BF_RIGHT);
    InflateRect(&area, -px(ui, 6), 0);
    SetBkMode(draw->hdc, TRANSPARENT);
    SetTextColor(draw->hdc, ui->text_color);
    if (item.fmt & (HDF_SORTUP | HDF_SORTDOWN)) {
        RECT arrow = area;
        arrow.left = arrow.right - px(ui, 12);
        DrawTextW(draw->hdc, (item.fmt & HDF_SORTUP) ? L"\x25B4" : L"\x25BE", -1, &arrow,
                  DT_CENTER | DT_SINGLELINE | DT_VCENTER);
        area.right = arrow.left;
    }
    UINT align = (item.fmt & HDF_RIGHT) ? DT_RIGHT : DT_LEFT;
    DrawTextW(draw->hdc, title, -1, &area, align | DT_SINGLELINE | DT_VCENTER | DT_END_ELLIPSIS);
    return CDRF_SKIPDEFAULT;
}

/* User32 owns hit testing, mnemonic keys and accessibility for the footer
 * buttons. Custom draw supplies their palette under explicit dark appearance. */
static LRESULT dark_button(DrillWindow *ui, NMCUSTOMDRAW *draw) {
    if (draw->dwDrawStage != CDDS_PREPAINT) return CDRF_DODEFAULT;
    DWORD state = draw->uItemState;
    RECT rect = draw->rc;
    SetDCBrushColor(draw->hdc, (state & CDIS_SELECTED) ? RGB(66,66,66) :
                               (state & CDIS_HOT) ? RGB(57,57,57) : RGB(48,48,48));
    FillRect(draw->hdc, &rect, GetStockObject(DC_BRUSH));
    SetDCBrushColor(draw->hdc, RGB(115,115,115));
    FrameRect(draw->hdc, &rect, GetStockObject(DC_BRUSH));
    SetTextColor(draw->hdc, (state & CDIS_DISABLED) ? RGB(155,155,155) : ui->text_color);
    SetBkMode(draw->hdc, TRANSPARENT);
    WCHAR label[32];
    GetWindowTextW(draw->hdr.hwndFrom, label, ARRAYSIZE(label));
    UINT flags = DT_SINGLELINE | DT_VCENTER | DT_CENTER;
    LRESULT cues = SendMessageW(draw->hdr.hwndFrom, WM_QUERYUISTATE, 0, 0);
    if (cues & UISF_HIDEACCEL) flags |= DT_HIDEPREFIX;
    DrawTextW(draw->hdc, label, -1, &rect, flags);
    if ((state & CDIS_FOCUS) && !(cues & UISF_HIDEFOCUS)) {
        InflateRect(&rect, -px(ui, 3), -px(ui, 3));
        DrawFocusRect(draw->hdc, &rect);
    }
    return CDRF_SKIPDEFAULT;
}

static LRESULT CALLBACK control_proc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp, UINT_PTR sub, DWORD_PTR data) {
    DrillWindow *ui = (DrillWindow *)data;
    if (hwnd == ui->query) {
        // A standard EDIT has one undo record. EM_UNDO toggles that record, including
        // when invoked through the native edit context menu.
        if (msg == WM_UNDO || msg == EM_UNDO) {
            bool can_undo = SendMessageW(hwnd, EM_CANUNDO, 0, 0) != 0;
            bool next_is_redo = !ui->redo_available;
            LRESULT result = DefSubclassProc(hwnd, msg, wp, lp);
            ui->redo_available = can_undo && next_is_redo;
            return result;
        }
        if (msg == WM_IME_STARTCOMPOSITION) ui->composing = true;
        if (msg == WM_IME_ENDCOMPOSITION) ui->composing = false;
    }
    if (hwnd == ui->table) {
        if (msg == WM_LBUTTONDOWN) {
            LVHITTESTINFO hit = {0};
            hit.pt.x = GET_X_LPARAM(lp);
            hit.pt.y = GET_Y_LPARAM(lp);
            ui->press_id = id_at(ui, ListView_SubItemHitTest(hwnd, &hit));
        }
        if (msg == WM_CONTEXTMENU && (HWND)wp == hwnd) {
            context_at(ui, lp);
            return 0;
        }
        if (msg == WM_NOTIFY && ui->dark) {
            NMHDR *note = (NMHDR *)lp;
            if (note->hwndFrom == ListView_GetHeader(hwnd) && note->code == NM_CUSTOMDRAW) {
                return dark_header(ui, (NMCUSTOMDRAW *)note);
            }
        }
    }
    if (msg == WM_GETDLGCODE && lp && ((MSG *)lp)->message == WM_KEYDOWN &&
        (wp == VK_UP || wp == VK_DOWN || wp == VK_RETURN || wp == VK_ESCAPE)) {
        return DefSubclassProc(hwnd, msg, wp, lp) | DLGC_WANTMESSAGE;
    }
    if (msg == WM_KEYDOWN && !ui->composing) {
        if (plain_key()) {
            int index = selected_index(ui);
            if (wp == VK_ESCAPE) {
                SendMessageW(ui->hwnd, WM_CLOSE, 0, 0);
                return 0;
            }
            if (wp == VK_RETURN) {
                // A held Return opens one result, even if the Shell pumps messages.
                if (HIWORD(lp) & KF_REPEAT) return 0;
                uint64_t id = id_at(ui, index);
                if (id) drill_win_open(ui->actions, id);
                return 0;
            }
            if (hwnd == ui->query && (wp == VK_DOWN || wp == VK_UP)) {
                int count = ListView_GetItemCount(ui->table);
                choose_index(ui, wp == VK_DOWN ? min(count - 1, index + 1) : max(-1, index - 1));
                return 0;
            }
            if (hwnd == ui->table && wp == VK_UP && index == 0) {
                choose_index(ui, -1);
                SetFocus(ui->query);
                return 0;
            }
        }
    }
    if (msg == WM_CHAR && !ui->composing && (wp == VK_RETURN || wp == VK_ESCAPE)) return 0;
    if (msg == WM_NCDESTROY) RemoveWindowSubclass(hwnd, control_proc, sub);
    return DefSubclassProc(hwnd, msg, wp, lp);
}

static void validate_menu(DrillWindow *ui) {
    HWND focus = GetFocus();
    bool editing = focus == ui->query;
    bool selected = selected_index(ui) >= 0;
    DWORD start = 0, end = 0;
    if (editing) SendMessageW(ui->query, EM_GETSEL, (WPARAM)&start, (LPARAM)&end);
    bool undo = editing && SendMessageW(ui->query, EM_CANUNDO, 0, 0);
    drill_windows_menu_enable(ui->menu, MENU_OPEN, selected);
    drill_windows_menu_enable(ui->menu, MENU_UNDO, undo && !ui->redo_available);
    drill_windows_menu_enable(ui->menu, MENU_REDO, undo && ui->redo_available);
    drill_windows_menu_enable(ui->menu, MENU_CUT, start != end);
    drill_windows_menu_enable(ui->menu, MENU_COPY, start != end || (focus == ui->table && selected));
    drill_windows_menu_enable(ui->menu, MENU_PASTE, editing && IsClipboardFormatAvailable(CF_UNICODETEXT));
    drill_windows_menu_enable(ui->menu, MENU_SELECT_ALL, editing && GetWindowTextLengthW(ui->query) > 0);
}

static void window_menu_command(const void *context, uint8_t command) {
    DrillWindow *ui = (DrillWindow *)context;
    HWND focus = GetFocus();
    switch (command) {
    case MENU_FIND:
        SetFocus(ui->query);
        Edit_SetSel(ui->query, 0, -1);
        break;
    case MENU_OPEN: {
        uint64_t id = id_at(ui, selected_index(ui));
        if (id) drill_win_open(ui->actions, id);
        break;
    }
    case MENU_CLOSE: SendMessageW(ui->hwnd, WM_CLOSE, 0, 0); break;
    case MENU_UNDO: case MENU_REDO:
        if (focus == ui->query && (command == MENU_REDO) == ui->redo_available)
            SendMessageW(focus, EM_UNDO, 0, 0);
        break;
    case MENU_CUT: if (focus == ui->query) SendMessageW(focus, WM_CUT, 0, 0); break;
    case MENU_PASTE: if (focus == ui->query) SendMessageW(focus, WM_PASTE, 0, 0); break;
    case MENU_SELECT_ALL: if (focus == ui->query) Edit_SetSel(focus, 0, -1); break;
    case MENU_COPY:
        if (focus == ui->query) SendMessageW(focus, WM_COPY, 0, 0);
        else if (focus == ui->table) {
            uint64_t id = id_at(ui, selected_index(ui));
            if (id) drill_win_copy_path(ui->actions, id);
        }
        break;
    case MENU_STOP: case MENU_CONTINUE:
        if (command == MENU_STOP) drill_stop(ui->model);
        else drill_continue(ui->model);
        update_window(ui);
        break;
    case MENU_INTERFACE: case MENU_SYNTAX:
        drill_win_show_panel(ui->actions, command == MENU_INTERFACE);
        break;
    }
}

static HWND add_control(DrillWindow *ui, DWORD ex, const WCHAR *kind, const WCHAR *caption,
                        DWORD styles, int id) {
    return CreateWindowExW(ex, kind, caption, WS_CHILD | WS_VISIBLE | styles,
                           0, 0, 0, 0, ui->hwnd, (HMENU)(INT_PTR)id, GetModuleHandleW(NULL), NULL);
}

static bool create_controls(DrillWindow *ui) {
    ui->query_label = add_control(ui, 0, L"STATIC", L"&Search", SS_CENTERIMAGE, -1);
    ui->query = add_control(ui, WS_EX_CLIENTEDGE, L"EDIT", L"", WS_TABSTOP | ES_AUTOHSCROLL, ID_QUERY);
    ui->mode_label = add_control(ui, 0, L"STATIC", L"Search &in", SS_CENTERIMAGE, -1);
    ui->mode = add_control(ui, 0, L"COMBOBOX", L"", WS_TABSTOP | WS_VSCROLL | CBS_DROPDOWNLIST, ID_MODE);
    ui->table = add_control(ui, WS_EX_CLIENTEDGE, WC_LISTVIEWW, L"Search results",
                            WS_TABSTOP | LVS_REPORT | LVS_SINGLESEL | LVS_SHOWSELALWAYS |
                            LVS_OWNERDATA | LVS_SHAREIMAGELISTS, ID_RESULTS);
    ui->status = add_control(ui, 0, L"STATIC", L"", SS_CENTERIMAGE | SS_NOPREFIX | SS_ENDELLIPSIS, ID_STATUS);
    ui->resume = add_control(ui, 0, L"BUTTON", L"&Continue", WS_TABSTOP | BS_PUSHBUTTON, ID_CONTINUE);
    ui->stop = add_control(ui, 0, L"BUTTON", L"S&top", WS_TABSTOP | BS_PUSHBUTTON, ID_STOP);
    if (!ui->query_label || !ui->query || !ui->mode_label || !ui->mode || !ui->table ||
        !ui->status || !ui->resume || !ui->stop) return false;
    if (ComboBox_AddString(ui->mode, L"Files") < 0 || ComboBox_AddString(ui->mode, L"Apps") < 0 ||
        !make_columns(ui)) return false;
    ComboBox_SetCurSel(ui->mode, 0);
    SendMessageW(ui->query, EM_SETCUEBANNER, TRUE, (LPARAM)L"Search files");
    // Set the text inset inside the native edit border.
    SendMessageW(ui->query, EM_SETMARGINS, EC_LEFTMARGIN | EC_RIGHTMARGIN, MAKELPARAM(px(ui, 5), px(ui, 5)));
    if (!SetWindowSubclass(ui->query, control_proc, ID_QUERY, (DWORD_PTR)ui) ||
        !SetWindowSubclass(ui->table, control_proc, ID_RESULTS, (DWORD_PTR)ui)) return false;
    ui->actions = drill_win_actions_create(ui->hwnd, ui->model, ui->table);
    if (!ui->actions) return false;
    ui->menu = drill_windows_menu_install(ui->hwnd, window_menu_command, ui);
    if (!ui->menu) return false;
    ui->accessibility = list_accessibility_create(ui->table, ui->model);
    apply_font(ui);
    apply_colors(ui);
    update_window(ui);
    layout_window(ui);
    return SetTimer(ui->hwnd, 1, 35, NULL) != 0;
}

static LRESULT CALLBACK search_window_proc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    DrillWindow *ui = (DrillWindow *)GetWindowLongPtrW(hwnd, GWLP_USERDATA);
    if (msg == WM_NCCREATE) {
        ui = ((CREATESTRUCTW *)lp)->lpCreateParams;
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, (LONG_PTR)ui);
        ui->hwnd = hwnd;
        ui->dpi = GetDpiForWindow(hwnd);
        if (!ui->dpi) ui->dpi = 96;
        ui->previous_width = px(ui, 682);
    }
    if (!ui) return DefWindowProcW(hwnd, msg, wp, lp);
    switch (msg) {
    case WM_CREATE: return create_controls(ui) ? 0 : -1;
    case WM_SETFOCUS:
        if (ui->query) SetFocus(ui->query);
        return 0;
    case WM_TIMER:
        if (wp == 1) update_window(ui);
        return 0;
    case WM_GETMINMAXINFO: {
        MINMAXINFO *size = (MINMAXINFO *)lp;
        size->ptMinTrackSize.x = px(ui, 480);
        size->ptMinTrackSize.y = px(ui, 300);
        return 0;
    }
    case WM_DPICHANGED: {
        UINT old = ui->dpi;
        ui->dpi = HIWORD(wp);
        if (ui->table && old) {
            for (int i = 0; i < 4; ++i) {
                int width = ListView_GetColumnWidth(ui->table, i);
                ListView_SetColumnWidth(ui->table, i, MulDiv(width, (int)ui->dpi, (int)old));
            }
            ui->previous_width = MulDiv(ui->previous_width, (int)ui->dpi, (int)old);
            apply_font(ui);
            drill_win_reset_icons(ui->actions);
        }
        RECT *rect = (RECT *)lp;
        SetWindowPos(hwnd, NULL, rect->left, rect->top, rect->right - rect->left,
                     rect->bottom - rect->top, SWP_NOACTIVATE | SWP_NOZORDER);
        return 0;
    }
    case WM_MOVE:
        record_placement(hwnd, &ui->placement);
        break;
    case WM_SIZE:
        record_placement(hwnd, &ui->placement);
        if (wp != SIZE_MINIMIZED) layout_window(ui);
        return 0;
    case WM_INITMENU:
        if (ui->menu) validate_menu(ui);
        break;
    case WM_COMMAND:
        if (LOWORD(wp) == ID_QUERY && HIWORD(wp) == EN_CHANGE) {
            ui->redo_available = false;
            search_changed(ui);
        }
        if (LOWORD(wp) == ID_MODE && HIWORD(wp) == CBN_SELCHANGE) search_changed(ui);
        if (LOWORD(wp) == ID_STOP && HIWORD(wp) == BN_CLICKED) window_menu_command(ui, MENU_STOP);
        if (LOWORD(wp) == ID_CONTINUE && HIWORD(wp) == BN_CLICKED) window_menu_command(ui, MENU_CONTINUE);
        if (LOWORD(wp) == IDCANCEL && !ui->composing) DestroyWindow(hwnd);
        return 0;
    case WM_NOTIFY: {
        NMHDR *note = (NMHDR *)lp;
        if (note->hwndFrom == ui->table) return table_notify(ui, note);
        if (ui->dark && note->code == NM_CUSTOMDRAW &&
            (note->hwndFrom == ui->resume || note->hwndFrom == ui->stop)) {
            return dark_button(ui, (NMCUSTOMDRAW *)note);
        }
        break;
    }
    case WM_CONTEXTMENU:
        if ((HWND)wp == ui->table) {
            context_at(ui, lp);
            return 0;
        }
        break;
    case DRILL_WM_SET_PREF:
        drill_win_set_preference(ui->actions, (unsigned)wp, (unsigned)lp);
        return 0;
    case DRILL_WM_PANEL_CLOSED:
        drill_win_panel_closed(ui->actions, (HWND)wp);
        return 0;
    case DRILL_WM_PREFERENCES:
        if (ui->actions) apply_colors(ui);
        return 0;
    case WM_THEMECHANGED:
    case WM_SYSCOLORCHANGE:
    case WM_SETTINGCHANGE:
        if (ui->actions) {
            drill_win_refresh_theme(ui->actions);
            apply_colors(ui);
        }
        break;
    case WM_ERASEBKGND:
        if (ui->background) {
            RECT area;
            GetClientRect(hwnd, &area);
            FillRect((HDC)wp, &area, ui->background);
            return 1;
        }
        break;
    case WM_CTLCOLOREDIT:
    case WM_CTLCOLORLISTBOX:
        if (ui->field) {
            SetTextColor((HDC)wp, ui->text_color);
            SetBkColor((HDC)wp, ui->list_color);
            return (LRESULT)ui->field;
        }
        break;
    case WM_CTLCOLORSTATIC:
        if (ui->background) {
            SetTextColor((HDC)wp, ui->dark ? ui->text_color : GetSysColor(COLOR_BTNTEXT));
            SetBkColor((HDC)wp, ui->face_color);
            return (LRESULT)ui->background;
        }
        break;
    case WM_CLOSE:
        DestroyWindow(hwnd);
        return 0;
    case WM_DESTROY:
        KillTimer(hwnd, 1);
        save_placement(&ui->placement);
        list_accessibility_destroy(ui->accessibility);
        ui->accessibility = NULL;
        drill_stop(ui->model);
        PostQuitMessage(0);
        return 0;
    case WM_NCDESTROY:
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, 0);
        ui->hwnd = NULL;
        break;
    }
    return DefWindowProcW(hwnd, msg, wp, lp);
}

int drill_native_run(DrillModel *model) {
    static const WCHAR name[] = L"DrillSearchWindow";
    if (!model) return 1;
    HRESULT com = CoInitializeEx(NULL, COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE);
    if (FAILED(com)) return 1;
    HINSTANCE instance = GetModuleHandleW(NULL);
    WNDCLASSEXW wc = {0};
    wc.cbSize = sizeof(wc);
    wc.hInstance = instance;
    wc.lpszClassName = name;
    wc.lpfnWndProc = search_window_proc;
    wc.hCursor = LoadCursorW(NULL, IDC_ARROW);
    wc.hIcon = LoadIconW(instance, MAKEINTRESOURCEW(1));
    wc.hbrBackground = GetSysColorBrush(COLOR_BTNFACE);
    DrillWindow ui = {0};
    ui.model = model;
    ui.sort_column = -1;
    int result = 1;
    INITCOMMONCONTROLSEX controls = {sizeof(controls), ICC_LISTVIEW_CLASSES | ICC_STANDARD_CLASSES};
    if (InitCommonControlsEx(&controls) && RegisterClassExW(&wc)) {
        DWORD style = WS_OVERLAPPEDWINDOW | WS_CLIPCHILDREN;
        UINT dpi = GetDpiForSystem();
        RECT area = {0, 0, MulDiv(720, (int)dpi, 96), MulDiv(470, (int)dpi, 96)};
        AdjustWindowRectExForDpi(&area, style, TRUE, 0, dpi);
        HWND hwnd = CreateWindowExW(0, name, L"Drill", style, CW_USEDEFAULT, CW_USEDEFAULT,
                                    area.right - area.left, area.bottom - area.top,
                                    NULL, NULL, instance, &ui);
        if (hwnd) {
            int show = restore_placement(hwnd, &ui.placement);
            ShowWindow(hwnd, show);
            record_placement(hwnd, &ui.placement);
            SetFocus(ui.query);
            UpdateWindow(hwnd);
            MSG msg;
            int received;
            while ((received = next_window_message(&ui, &msg)) > 0) {
                if (drill_win_dialog_message(ui.actions, &msg) ||
                    (!ui.composing && drill_windows_menu_translate(ui.menu, &msg)) ||
                    IsDialogMessageW(hwnd, &msg)) continue;
                TranslateMessage(&msg);
                DispatchMessageW(&msg);
            }
            result = received < 0 ? 1 : (int)msg.wParam;
            if (IsWindow(hwnd)) DestroyWindow(hwnd);
        }
        if (ui.menu) drill_windows_menu_remove(ui.menu);
        if (ui.actions) drill_win_actions_destroy(ui.actions);
        DeleteObject(ui.font);
        DeleteObject(ui.field);
        DeleteObject(ui.background);
        UnregisterClassW(name, instance);
    }
    CoUninitialize();
    return result;
}
