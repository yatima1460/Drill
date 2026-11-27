#include <windows.h>
#include <oleacc.h>
#include <stdbool.h>

// Only the top-level labels change presentation. User32 owns the popup
// items and menu navigation in both appearances. MSAA reads the same labels.
#define DRILL_MENU_TITLE(text) { MSAA_MENU_SIG, ARRAYSIZE(text) - 1, text }
static const MSAAMENUINFO drill_menu_titles[] = {
    DRILL_MENU_TITLE(L"Search"), DRILL_MENU_TITLE(L"Settings"), DRILL_MENU_TITLE(L"Help")
};
#undef DRILL_MENU_TITLE

typedef struct {
    bool requested_dark;
    bool active_dark;
} DrillMenuAppearance;

static bool drill_menu_style(HMENU bar, bool dark) {
    for (UINT i = 0; i < ARRAYSIZE(drill_menu_titles); ++i) {
        const MSAAMENUINFO *label = &drill_menu_titles[i];
        MENUITEMINFOW item = {0};
        item.cbSize = sizeof(item);
        item.fMask = MIIM_FTYPE | MIIM_DATA | MIIM_STRING;
        item.dwTypeData = label->pszWText;
        item.fType = dark ? MFT_OWNERDRAW : MFT_STRING;
        item.dwItemData = dark ? (ULONG_PTR)label : 0;
        if (!SetMenuItemInfoW(bar, i, TRUE, &item)) {
            return false;
        }
    }
    MENUINFO info = {0};
    info.cbSize = sizeof(info);
    info.fMask = MIM_BACKGROUND;
    info.hbrBack = dark ? GetStockObject(BLACK_BRUSH) : NULL;
    return SetMenuInfo(bar, &info) != 0;
}

static void drill_menu_set_appearance(DrillMenuAppearance *appearance, HWND window,
                                      HMENU bar, bool requested_dark) {
    appearance->requested_dark = requested_dark;
    HIGHCONTRASTW contrast = {0};
    contrast.cbSize = sizeof(contrast);
    bool dark = requested_dark &&
        SystemParametersInfoW(SPI_GETHIGHCONTRAST, sizeof(contrast), &contrast, 0) &&
        !(contrast.dwFlags & HCF_HIGHCONTRASTON);
    if (dark == appearance->active_dark) {
        return;
    }
    if (drill_menu_style(bar, dark)) {
        appearance->active_dark = dark;
    } else {
        drill_menu_style(bar, appearance->active_dark);
    }
    DrawMenuBar(window);
}

static const MSAAMENUINFO *drill_menu_title(ULONG_PTR data) {
    // Other controls and menu items can also send owner-draw messages.
    for (size_t i = 0; i < ARRAYSIZE(drill_menu_titles); ++i) {
        if (data == (ULONG_PTR)&drill_menu_titles[i]) {
            return &drill_menu_titles[i];
        }
    }
    return NULL;
}

static HFONT drill_menu_font(HWND window, UINT *dpi) {
    NONCLIENTMETRICSW metrics = {0};
    metrics.cbSize = sizeof(metrics);
    // These documented per-monitor APIs arrived in Windows 10 version 1607.
    HMODULE user = GetModuleHandleW(L"user32.dll");
    union { FARPROC address; UINT (WINAPI *call)(HWND); } get_dpi = {
        GetProcAddress(user, "GetDpiForWindow")
    };
    union { FARPROC address; BOOL (WINAPI *call)(UINT, UINT, void *, UINT, UINT); } get_metrics = {
        GetProcAddress(user, "SystemParametersInfoForDpi")
    };
    if (get_dpi.call && get_metrics.call) {
        UINT local = get_dpi.call(window);
        if (local && get_metrics.call(SPI_GETNONCLIENTMETRICS, sizeof(metrics), &metrics, 0, local)) {
            *dpi = local;
            return CreateFontIndirectW(&metrics.lfMenuFont);
        }
    }
    if (SystemParametersInfoW(SPI_GETNONCLIENTMETRICS, sizeof(metrics), &metrics, 0)) {
        return CreateFontIndirectW(&metrics.lfMenuFont);
    }
    return NULL;
}

static bool drill_menu_draw_item(HWND window, UINT message, WPARAM wp, LPARAM lp) {
    if (!lp || wp != 0 || (message != WM_MEASUREITEM && message != WM_DRAWITEM)) {
        return false;
    }
    bool measuring = message == WM_MEASUREITEM;
    MEASUREITEMSTRUCT *measure = measuring ? (MEASUREITEMSTRUCT *)lp : NULL;
    const DRAWITEMSTRUCT *draw = measuring ? NULL : (const DRAWITEMSTRUCT *)lp;
    if ((measuring ? measure->CtlType : draw->CtlType) != ODT_MENU) {
        return false;
    }
    const MSAAMENUINFO *label = drill_menu_title(measuring ? measure->itemData : draw->itemData);
    if (!label) {
        return false;
    }
    HDC dc = measuring ? GetDC(window) : draw->hDC;
    if (!dc) {
        return false;
    }
    int saved = SaveDC(dc);
    bool ok = false;
    if (saved) {
        UINT dpi = (UINT)GetDeviceCaps(dc, LOGPIXELSY);
        HFONT font = drill_menu_font(window, &dpi);
        SelectObject(dc, font ? font : GetStockObject(DEFAULT_GUI_FONT));
        if (measuring) {
            SIZE text;
            if (GetTextExtentPoint32W(dc, label->pszWText, (int)label->cchWText, &text)) {
                measure->itemWidth = (UINT)text.cx;
                measure->itemHeight = (UINT)(text.cy + MulDiv(4, (int)dpi, 96));
                ok = true;
            }
        } else {
            UINT state = draw->itemState;
            bool disabled = (state & (ODS_DISABLED | ODS_GRAYED)) != 0;
            bool hot = !disabled && (state & (ODS_HOTLIGHT | ODS_SELECTED));
            RECT rect = draw->rcItem;
            SetDCBrushColor(dc, hot ? RGB(65, 65, 65) : RGB(0, 0, 0));
            FillRect(dc, &rect, GetStockObject(DC_BRUSH));
            SetBkMode(dc, TRANSPARENT);
            SetTextColor(dc, disabled ? RGB(150, 150, 150) : RGB(255, 255, 255));
            UINT format = DT_CENTER | DT_VCENTER | DT_SINGLELINE;
            if (state & ODS_NOACCEL) {
                format |= DT_HIDEPREFIX;
            }
            ok = DrawTextW(dc, label->pszWText, (int)label->cchWText, &rect, format) != 0;
            if (ok && (state & ODS_FOCUS) && !(state & ODS_NOFOCUSRECT)) {
                InflateRect(&rect, -1, -1);
                DrawFocusRect(dc, &rect);
            }
        }
        RestoreDC(dc, saved);
        if (font) {
            DeleteObject(font);
        }
    }
    if (measuring) {
        ReleaseDC(window, dc);
    }
    return ok;
}

// WM_MENUCHAR asks the owner to resolve a keyboard choice for an owner-drawn
// item. Cycle between equal initials and open a uniquely matching submenu.
static LRESULT drill_menu_character(HMENU bar, WCHAR key) {
    if (key >= L'a' && key <= L'z') {
        key -= L'a' - L'A';
    }
    int first = -1, next = -1, highlighted = -1;
    unsigned matches = 0;
    for (UINT i = 0; i < ARRAYSIZE(drill_menu_titles); ++i) {
        UINT state = GetMenuState(bar, i, MF_BYPOSITION);
        if (state == (UINT)-1) {
            return 0;
        }
        if (state & MF_HILITE) {
            highlighted = (int)i;
        }
    }
    for (UINT i = 0; i < ARRAYSIZE(drill_menu_titles); ++i) {
        UINT state = GetMenuState(bar, i, MF_BYPOSITION);
        if (drill_menu_titles[i].pszWText[0] == key && !(state & (MF_GRAYED | MF_DISABLED))) {
            ++matches;
            if (first < 0) first = (int)i;
            if (next < 0 && (int)i > highlighted) next = (int)i;
        }
    }
    return matches ? MAKELRESULT(next >= 0 ? next : first, matches == 1 ? MNC_EXECUTE : MNC_SELECT) : 0;
}
