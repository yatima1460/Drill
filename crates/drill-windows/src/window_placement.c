/* Screen coordinates throughout: GetWindowRect and SetWindowPos also agree
 * when a taskbar occupies the top or left of a monitor. Persist the normal
 * frame separately from the maximized state, including when closed minimized. */
typedef struct {
    RECT normal;
    UINT dpi;
    DWORD maximized;
} DrillPlacement;

static const WCHAR placement_value[] = L"WindowPlacement";

static bool valid_placement(const DrillPlacement *p) {
    int64_t width = (int64_t)p->normal.right - p->normal.left;
    int64_t height = (int64_t)p->normal.bottom - p->normal.top;
    return width > 0 && height > 0 && width <= 65536 && height <= 65536 &&
           p->normal.left >= -1048576 && p->normal.left <= 1048576 &&
           p->normal.top >= -1048576 && p->normal.top <= 1048576 &&
           p->dpi >= 48 && p->dpi <= 960 && p->maximized <= 1;
}

static void record_placement(HWND hwnd, DrillPlacement *p) {
    if (!IsWindowVisible(hwnd) || IsIconic(hwnd)) return;
    p->maximized = IsZoomed(hwnd) != FALSE;
    if (!p->maximized) {
        GetWindowRect(hwnd, &p->normal);
        p->dpi = GetDpiForWindow(hwnd);
    }
}

static void save_placement(const DrillPlacement *p) {
    if (valid_placement(p)) {
        RegSetKeyValueW(HKEY_CURRENT_USER, win_pref_key, placement_value,
                        REG_BINARY, p, sizeof(*p));
    }
}

static void fit_to_work_area(RECT *frame, const RECT *work, int width, int height) {
    width = min(width, work->right - work->left);
    height = min(height, work->bottom - work->top);
    frame->left = max(work->left, min(frame->left, work->right - width));
    frame->top = max(work->top, min(frame->top, work->bottom - height));
    frame->right = frame->left + width;
    frame->bottom = frame->top + height;
}

static void move_to_frame(HWND hwnd, const RECT *frame) {
    SetWindowPos(hwnd, NULL, frame->left, frame->top, frame->right - frame->left,
                 frame->bottom - frame->top, SWP_NOZORDER | SWP_NOACTIVATE);
}

static int restore_placement(HWND hwnd, DrillPlacement *p) {
    DWORD bytes = sizeof(*p);
    LSTATUS read = RegGetValueW(HKEY_CURRENT_USER, win_pref_key, placement_value,
                                RRF_RT_REG_BINARY, NULL, p, &bytes);
    bool native = read == ERROR_SUCCESS && bytes == sizeof(*p) && valid_placement(p);
    SIZE legacy_size = {0};
    if (!native) {
        POINT origin;
        bool maximized;
        if (read != ERROR_FILE_NOT_FOUND || !win_read_legacy_placement(&origin, &legacy_size, &maximized)) {
            GetWindowRect(hwnd, &p->normal);
            p->dpi = GetDpiForWindow(hwnd);
            p->maximized = 0;
            return SW_SHOWNORMAL;
        }
        p->normal.left = origin.x;
        p->normal.top = origin.y;
        p->normal.right = origin.x + legacy_size.cx;
        p->normal.bottom = origin.y + legacy_size.cy;
        p->maximized = maximized;
        p->dpi = 96;
    }
    DrillPlacement saved = *p;
    HMONITOR monitor = MonitorFromRect(&saved.normal, MONITOR_DEFAULTTONEAREST);
    MONITORINFO info = {0};
    info.cbSize = sizeof(info);
    if (!GetMonitorInfoW(monitor, &info)) return SW_SHOWNORMAL;

    // Position the hidden window on the destination monitor first. This gives
    // the effective DPI for its current configuration and decorations.
    RECT frame = saved.normal;
    int width = frame.right - frame.left, height = frame.bottom - frame.top;
    fit_to_work_area(&frame, &info.rcWork, width, height);
    move_to_frame(hwnd, &frame);
    UINT dpi = GetDpiForWindow(hwnd);
    if (!dpi) dpi = 96;
    if (native) {
        width = MulDiv(width, (int)dpi, (int)saved.dpi);
        height = MulDiv(height, (int)dpi, (int)saved.dpi);
    } else {
        RECT client = {0, 0, MulDiv(legacy_size.cx, (int)dpi, 96),
                            MulDiv(legacy_size.cy, (int)dpi, 96)};
        AdjustWindowRectExForDpi(&client, (DWORD)GetWindowLongPtrW(hwnd, GWL_STYLE),
                                 TRUE, (DWORD)GetWindowLongPtrW(hwnd, GWL_EXSTYLE), dpi);
        width = client.right - client.left;
        height = client.bottom - client.top;
    }
    frame = saved.normal;
    fit_to_work_area(&frame, &info.rcWork, max(width, MulDiv(480, (int)dpi, 96)),
                                          max(height, MulDiv(300, (int)dpi, 96)));
    move_to_frame(hwnd, &frame);
    GetWindowRect(hwnd, &p->normal);
    p->dpi = dpi;
    p->maximized = saved.maximized;
    return saved.maximized ? SW_SHOWMAXIMIZED : SW_SHOWNORMAL;
}
