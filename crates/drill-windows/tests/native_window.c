// Runs the shipping executable on a controlled desktop. Mouse, keyboard and
// clipboard operations use the same controls and shortcuts as a human user.
#define COBJMACROS
#ifndef UNICODE
#define UNICODE
#endif
#include <windows.h>
#include <commctrl.h>
#include <oleacc.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>

static const char *stage = "startup";
static bool use_msaa = true;
static const WCHAR bridge_marker[] = L"DRILL_WINE_BUNDLE_PIPE";
static HANDLE bridge_input, bridge_output;
static PROCESS_INFORMATION app;
static HWND window, edit, combo, list, header, status;
static WCHAR root[MAX_PATH];
static const WCHAR *const files[] = {
    L"win-native-a-\U0001F9EA.txt", L"win-native-z.txt", L"win-native-m.exe", L"opened.marker", L"green test icon.exe"
};
static WCHAR paths[ARRAYSIZE(files)][MAX_PATH];

static void fail(const char *message) {
    fprintf(stderr, "Native window test failed during %s: %s (Win32 error %lu)\n", stage, message, GetLastError());
    exit(1);
}
#define REQUIRE(test) do { if (!(test)) fail(#test); } while (0)

typedef struct {
    const WCHAR *subkey, *name;
    DWORD type, bytes;
    BYTE *data;
} SavedValue;
static SavedValue saved_values[8];
static size_t saved_count;

// Run the shipping app through its actual per-user registry preferences and
// restore the original type, bytes, or absence even if an assertion fails.
static void preserve_value(const WCHAR *subkey, const WCHAR *name) {
    REQUIRE(saved_count < ARRAYSIZE(saved_values));
    SavedValue *value = &saved_values[saved_count];
    value->subkey = subkey;
    value->name = name;
    HKEY key = NULL;
    LSTATUS result = RegOpenKeyExW(HKEY_CURRENT_USER, subkey, 0, KEY_QUERY_VALUE, &key);
    if (result == ERROR_SUCCESS) {
        result = RegQueryValueExW(key, name, NULL, &value->type, NULL, &value->bytes);
        if (result == ERROR_SUCCESS) {
            value->data = calloc(value->bytes ? value->bytes : 1, 1);
            REQUIRE(value->data);
            result = RegQueryValueExW(key, name, NULL, &value->type, value->data, &value->bytes);
        }
        RegCloseKey(key);
    }
    REQUIRE(result == ERROR_SUCCESS || result == ERROR_FILE_NOT_FOUND || result == ERROR_PATH_NOT_FOUND);
    ++saved_count;
}

static void clean_up(void) {
    if (app.hProcess) {
        if (WaitForSingleObject(app.hProcess, 0) == WAIT_TIMEOUT) {
            TerminateProcess(app.hProcess, 1);
            WaitForSingleObject(app.hProcess, 5000);
        }
        CloseHandle(app.hProcess);
    }
    for (size_t i = 0; i < saved_count; ++i) {
        SavedValue *value = &saved_values[i];
        if (value->data) {
            RegSetKeyValueW(HKEY_CURRENT_USER, value->subkey, value->name, value->type, value->data, value->bytes);
            free(value->data);
        } else {
            RegDeleteKeyValueW(HKEY_CURRENT_USER, value->subkey, value->name);
        }
    }
    for (unsigned i = 0; i < ARRAYSIZE(files); ++i) {
        if (*paths[i]) DeleteFileW(paths[i]);
    }
    if (*root) RemoveDirectoryW(root);
}

static void create_file(const WCHAR *path) {
    HANDLE file = CreateFileW(path, GENERIC_WRITE, 0, NULL, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, NULL);
    REQUIRE(file != INVALID_HANDLE_VALUE);
    CloseHandle(file);
}

static void fixture(const WCHAR *self) {
    WCHAR temp[MAX_PATH], candidate[MAX_PATH];
    DWORD n = GetTempPathW(ARRAYSIZE(temp), temp);
    REQUIRE(n && n < ARRAYSIZE(temp));
    // Only clean up a directory that this invocation successfully created.
    int chars = swprintf(candidate, ARRAYSIZE(candidate), L"%lsDrill controls %lu-%llu", temp,
                         GetCurrentProcessId(), (unsigned long long)GetTickCount64());
    REQUIRE(chars > 0 && (size_t)chars < ARRAYSIZE(candidate));
    REQUIRE(CreateDirectoryW(candidate, NULL));
    lstrcpyW(root, candidate);
    for (unsigned i = 0; i < ARRAYSIZE(files); ++i) {
        chars = swprintf(paths[i], MAX_PATH, L"%ls\\%ls", root, files[i]);
        REQUIRE(chars > 0 && chars < MAX_PATH);
    }
    create_file(paths[1]);
    create_file(paths[0]);
    REQUIRE(CopyFileW(self, paths[2], TRUE));
    REQUIRE(CopyFileW(L"tools\\exe-icon-wasm\\tests\\fixtures\\icon-pe32.exe", paths[4], TRUE));
}

// The host wrapper gives this driver the protocol streams for its final
// bundle test. Keep them out of the standard handles of the ordinary app and
// the harmless executable it launches during the shell-action test.
static void reserve_bridge(void) {
    WCHAR enabled[2];
    REQUIRE(GetEnvironmentVariableW(bridge_marker, enabled, ARRAYSIZE(enabled)) == 1 && enabled[0] == L'1');
    bridge_input = GetStdHandle(STD_INPUT_HANDLE);
    bridge_output = GetStdHandle(STD_OUTPUT_HANDLE);
    REQUIRE(bridge_input && bridge_output && bridge_output != GetStdHandle(STD_ERROR_HANDLE));
    REQUIRE(SetHandleInformation(bridge_input, HANDLE_FLAG_INHERIT, 0));
    REQUIRE(SetHandleInformation(bridge_output, HANDLE_FLAG_INHERIT, 0));
    REQUIRE(SetEnvironmentVariableW(bridge_marker, NULL));
    REQUIRE(SetStdHandle(STD_INPUT_HANDLE, NULL));
    REQUIRE(SetStdHandle(STD_OUTPUT_HANDLE, GetStdHandle(STD_ERROR_HANDLE)));
}

static HANDLE inherited_stream(HANDLE stream) {
    HANDLE copy = NULL;
    REQUIRE(DuplicateHandle(GetCurrentProcess(), stream, GetCurrentProcess(),
                            &copy, 0, TRUE, DUPLICATE_SAME_ACCESS));
    return copy;
}

static void launch(const WCHAR *path, const WCHAR *directory, bool with_bridge) {
    WCHAR executable[MAX_PATH], command[2 * MAX_PATH + 32];
    DWORD n = GetFullPathNameW(path, ARRAYSIZE(executable), executable, NULL);
    REQUIRE(n && n < ARRAYSIZE(executable));
    int chars = swprintf(command, ARRAYSIZE(command), L"\"%ls\" --root \"%ls\"", executable, directory);
    REQUIRE(chars > 0 && (size_t)chars < ARRAYSIZE(command));
    STARTUPINFOW startup = {0};
    startup.cb = sizeof(startup);
    REQUIRE(!app.hProcess);
    if (with_bridge) {
        startup.dwFlags = STARTF_USESTDHANDLES;
        startup.hStdInput = inherited_stream(bridge_input);
        startup.hStdOutput = inherited_stream(bridge_output);
        startup.hStdError = inherited_stream(GetStdHandle(STD_ERROR_HANDLE));
        REQUIRE(SetEnvironmentVariableW(bridge_marker, L"1"));
    }
    BOOL created = CreateProcessW(executable, command, NULL, NULL, with_bridge, 0, NULL, NULL, &startup, &app);
    if (with_bridge) {
        REQUIRE(SetEnvironmentVariableW(bridge_marker, NULL));
        CloseHandle(startup.hStdInput);
        CloseHandle(startup.hStdOutput);
        CloseHandle(startup.hStdError);
    }
    REQUIRE(created);
    CloseHandle(app.hThread);
}

static bool retry(ULONGLONG deadline) {
    DWORD exit_code;
    REQUIRE(GetExitCodeProcess(app.hProcess, &exit_code));
    if (exit_code != STILL_ACTIVE) {
        fprintf(stderr, "Drill exited with %lu\n", exit_code);
        fail("unexpected application exit");
    }
    Sleep(20);
    return GetTickCount64() < deadline;
}

typedef struct {
    const WCHAR *class_name;
    const WCHAR *title;
    HWND result;
} WindowSearch;

static BOOL CALLBACK match_window(HWND hwnd, LPARAM parameter) {
    WindowSearch *search = (WindowSearch *)parameter;
    WCHAR name[64], title[64];
    DWORD process = 0;
    GetWindowThreadProcessId(hwnd, &process);
    if (process != app.dwProcessId || !IsWindowVisible(hwnd)) return TRUE;
    if (GetClassNameW(hwnd, name, ARRAYSIZE(name)) && wcscmp(name, search->class_name) == 0 &&
        GetWindowTextW(hwnd, title, ARRAYSIZE(title)) && wcscmp(title, search->title) == 0) {
        search->result = hwnd;
        return FALSE;
    }
    return TRUE;
}

static HWND find_window(const WCHAR *class_name, const WCHAR *title) {
    ULONGLONG deadline = GetTickCount64() + 20000;
    WindowSearch search = {class_name, title, NULL};
    do {
        EnumWindows(match_window, (LPARAM)&search);
        if (search.result) return search.result;
    } while (retry(deadline));
    fwprintf(stderr, L"Missing window '%ls' (%ls)\n", title, class_name);
    fail("window did not appear");
    return NULL;
}

static HWND control(HWND parent, int id, const WCHAR *expected) {
    HWND child = GetDlgItem(parent, id);
    WCHAR actual[64];
    REQUIRE(child && GetClassNameW(child, actual, ARRAYSIZE(actual)));
    REQUIRE(_wcsicmp(actual, expected) == 0);
    return child;
}

static LRESULT message(HWND target, UINT id, WPARAM w, LPARAM l) {
    DWORD_PTR result = 0;
    REQUIRE(SendMessageTimeoutW(target, id, w, l, SMTO_ABORTIFHUNG | SMTO_BLOCK,
                                3000, &result));
    return (LRESULT)result;
}

static void expect_text(HWND target, const WCHAR *text) {
    WCHAR actual[2 * MAX_PATH];
    ULONGLONG deadline = GetTickCount64() + 5000;
    do {
        message(target, WM_GETTEXT, ARRAYSIZE(actual), (LPARAM)actual);
        if (wcscmp(actual, text) == 0) return;
    } while (retry(deadline));
    fwprintf(stderr, L"Expected '%ls', read '%ls'\n", text, actual);
    fail("unexpected control text");
}

static void results(int count) {
    ULONGLONG deadline = GetTickCount64() + 15000;
    WCHAR label[256], expected[64];
    swprintf(expected, ARRAYSIZE(expected), L"%d %ls", count, count == 1 ? L"result" : L"results");
    do {
        message(status, WM_GETTEXT, ARRAYSIZE(label), (LPARAM)label);
        if (message(list, LVM_GETITEMCOUNT, 0, 0) == count && wcscmp(label, expected) == 0 &&
            !IsWindowEnabled(GetDlgItem(window, 105))) return;
    } while (retry(deadline));
    fwprintf(stderr, L"Expected %d results, found %lld; status '%ls'\n",
             count, (long long)message(list, LVM_GETITEMCOUNT, 0, 0), label);
    fail("search did not finish");
}

static void selected(int index) {
    ULONGLONG deadline = GetTickCount64() + 5000;
    do {
        if (message(list, LVM_GETNEXTITEM, (WPARAM)-1, LVNI_SELECTED) == index) return;
    } while (retry(deadline));
    fail("unexpected selected row");
}

static void activate_main(void) {
    if (GetForegroundWindow() == window) return;
    SetForegroundWindow(window);
    ULONGLONG deadline = GetTickCount64() + 5000;
    while (GetForegroundWindow() != window) REQUIRE(retry(deadline));
}

static void send_events(INPUT *events, UINT count) {
    DWORD pid = 0;
    GetWindowThreadProcessId(GetForegroundWindow(), &pid);
    REQUIRE(pid == app.dwProcessId);
    REQUIRE(SendInput(count, events, sizeof(INPUT)) == count);
}

static void click_point(HWND target, POINT point) {
    // An HWND becomes visible before an external window manager has finished
    // mapping or repositioning its surface. Keep the intended client point and
    // re-evaluate it on screen before sending any physical input.
    POINT client = point;
    REQUIRE(ScreenToClient(target, &client));
    ULONGLONG deadline = GetTickCount64() + 5000;
    HWND hit;
    for (;;) {
        point = client;
        REQUIRE(IsWindow(target) && ClientToScreen(target, &point));
        hit = WindowFromPoint(point);
        if (IsWindowVisible(target) && IsWindowEnabled(target) &&
            (hit == target || IsChild(target, hit))) break;
        if (!retry(deadline)) {
            WCHAR target_class[64] = {0}, hit_class[64] = {0}, hit_title[96] = {0};
            GetClassNameW(target, target_class, ARRAYSIZE(target_class));
            GetClassNameW(hit, hit_class, ARRAYSIZE(hit_class));
            GetWindowTextW(GetAncestor(hit, GA_ROOT), hit_title, ARRAYSIZE(hit_title));
            fprintf(stderr, "%s: target %p %ls id %d at (%ld,%ld); hit %p %ls id %d, top '%ls'\n",
                    stage, (void *)target, target_class, GetDlgCtrlID(target), point.x, point.y,
                    (void *)hit, hit_class, GetDlgCtrlID(hit), hit_title);
            fail("target did not receive the pointer hit test");
        }
    }
    // Submit the move and both buttons together so queued clicks on different
    // controls retain their own positions even when the application is busy.
    INPUT events[3] = {0};
    for (unsigned i = 0; i < ARRAYSIZE(events); ++i) events[i].type = INPUT_MOUSE;
    events[0].mi.dwFlags = MOUSEEVENTF_ABSOLUTE | MOUSEEVENTF_MOVE | MOUSEEVENTF_VIRTUALDESK;
    events[0].mi.dx = MulDiv(point.x - GetSystemMetrics(SM_XVIRTUALSCREEN), 65535,
                             GetSystemMetrics(SM_CXVIRTUALSCREEN) - 1);
    events[0].mi.dy = MulDiv(point.y - GetSystemMetrics(SM_YVIRTUALSCREEN), 65535,
                             GetSystemMetrics(SM_CYVIRTUALSCREEN) - 1);
    events[1].mi.dwFlags = MOUSEEVENTF_LEFTDOWN;
    events[2].mi.dwFlags = MOUSEEVENTF_LEFTUP;
    send_events(events, ARRAYSIZE(events));
}

static POINT near_left(HWND target) {
    RECT r;
    REQUIRE(GetWindowRect(target, &r));
    POINT point = {r.left + 12, (r.top + r.bottom) / 2};
    return point;
}

static void click(HWND target) {
    click_point(target, near_left(target));
}

static POINT first_row(void) {
    RECT bounds;
    REQUIRE(GetWindowRect(header, &bounds));
    POINT point = {bounds.left + 42, bounds.bottom + 8};
    return point;
}

static void accessible_first_row(const WCHAR *filename) {
    if (!use_msaa) return;
    IAccessible *owner = NULL;
    VARIANT child = {0}, role = {0};
    BSTR name = NULL, description = NULL;
    REQUIRE(AccessibleObjectFromPoint(first_row(), &owner, &child) == S_OK && owner);
    REQUIRE(IAccessible_get_accRole(owner, child, &role) == S_OK);
    REQUIRE(role.vt == VT_I4 && role.lVal == ROLE_SYSTEM_LISTITEM);
    REQUIRE(IAccessible_get_accName(owner, child, &name) == S_OK && name);
    REQUIRE(wcscmp(name, filename) == 0);
    REQUIRE(IAccessible_get_accDescription(owner, child, &description) == S_OK && description);
    REQUIRE(_wcsnicmp(description, root, wcslen(root)) == 0 && description[wcslen(root)] == L',');
    SysFreeString(description);
    SysFreeString(name);
    VariantClear(&role);
    VariantClear(&child);
    IAccessible_Release(owner);
}

static void key(WORD vk, bool ctrl) {
    INPUT events[4] = {0};
    UINT count = 0;
    if (ctrl) events[count++].ki.wVk = VK_CONTROL;
    events[count++].ki.wVk = vk;
    events[count].ki.wVk = vk;
    events[count++].ki.dwFlags = KEYEVENTF_KEYUP;
    if (ctrl) {
        events[count].ki.wVk = VK_CONTROL;
        events[count++].ki.dwFlags = KEYEVENTF_KEYUP;
    }
    for (UINT i = 0; i < count; ++i) {
        events[i].type = INPUT_KEYBOARD;
        WORD code = events[i].ki.wVk;
        if (code == VK_UP || code == VK_DOWN || code == VK_LEFT || code == VK_HOME || code == VK_END) {
            events[i].ki.dwFlags |= KEYEVENTF_EXTENDEDKEY;
        }
    }
    send_events(events, count);
}

static void type_text(const WCHAR *text) {
    for (; *text; ++text) {
        INPUT events[2] = {0};
        events[0].type = events[1].type = INPUT_KEYBOARD;
        events[0].ki.wScan = events[1].ki.wScan = *text;
        events[0].ki.dwFlags = KEYEVENTF_UNICODE;
        events[1].ki.dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP;
        send_events(events, ARRAYSIZE(events));
    }
}

static void copy_and_expect(const WCHAR *expected) {
    DWORD previous = GetClipboardSequenceNumber();
    key('C', true);
    ULONGLONG deadline = GetTickCount64() + 5000;
    do {
        if (GetClipboardSequenceNumber() != previous && OpenClipboard(NULL)) {
            HANDLE data = GetClipboardData(CF_UNICODETEXT);
            const WCHAR *value = data ? GlobalLock(data) : NULL;
            bool equal = value && _wcsicmp(value, expected) == 0;
            if (value) GlobalUnlock(data);
            CloseClipboard();
            if (equal) return;
        }
    } while (retry(deadline));
    fwprintf(stderr, L"Copy did not put '%ls' on the Unicode clipboard.\n", expected);
    fail("copy selection");
}

static void search_and_sort(void) {
    click(edit);
    type_text(L"win-native-");
    expect_text(edit, L"win-native-");
    results(3);
    REQUIRE(GetFileAttributesW(paths[3]) == INVALID_FILE_ATTRIBUTES);
    type_text(L"*.txt");
    expect_text(edit, L"win-native-*.txt");
    results(2);
    selected(-1);
    key(VK_DOWN, false);
    selected(0);
    key(VK_UP, false);
    selected(-1);

    click(header);
    click_point(list, first_row());
    selected(0);
    copy_and_expect(paths[0]);
    accessible_first_row(files[0]);
    // The same Unicode result must remain selected as its display index changes.
    click(header);
    selected(1);
    click_point(list, first_row());
    selected(0);
    copy_and_expect(paths[1]);
    accessible_first_row(files[1]);

    key('F', true);
    GUITHREADINFO focus = {0};
    focus.cbSize = sizeof(focus);
    ULONGLONG deadline = GetTickCount64() + 5000;
    do {
        REQUIRE(GetGUIThreadInfo(app.dwThreadId, &focus));
        if (focus.hwndFocus == edit) break;
        REQUIRE(retry(deadline));
    } while (true);
    DWORD selected_start = 0, selected_end = 0;
    message(edit, EM_GETSEL, (WPARAM)&selected_start, (LPARAM)&selected_end);
    REQUIRE(selected_start == 0 && selected_end == wcslen(L"win-native-*.txt"));
    message(edit, EM_SETSEL, 0, 10);
    copy_and_expect(L"win-native");
    key('A', true);
    key('V', true);
    expect_text(edit, L"win-native");
    results(3);
    selected(-1);
    key('Z', true);
    expect_text(edit, L"win-native-*.txt");
    results(2);
    key('Y', true);
    expect_text(edit, L"win-native");
    results(3);
}

// Each copy of the fixture app appends one byte. Concurrent activations must be
// visible independently, including ones which start after a shortcut returns.
static DWORD launches(void) {
    WIN32_FILE_ATTRIBUTE_DATA attr;
    if (!GetFileAttributesExW(paths[3], GetFileExInfoStandard, &attr)) {
        REQUIRE(GetLastError() == ERROR_FILE_NOT_FOUND);
        return 0;
    }
    REQUIRE(attr.nFileSizeHigh == 0);
    return attr.nFileSizeLow;
}

static void wait_for_launches(DWORD expected) {
    ULONGLONG deadline = GetTickCount64() + 10000;
    while (launches() < expected) REQUIRE(retry(deadline));
    REQUIRE(launches() == expected);
}

static void filter_and_launch(void) {
    // A click opens the drop-down list on Windows. End and Return commit Apps.
    click(combo);
    key(VK_END, false);
    key(VK_RETURN, false);
    results(1);
    REQUIRE(message(combo, CB_GETCURSEL, 0, 0) == 1);
    click_point(list, first_row());
    selected(0);
    copy_and_expect(paths[2]);
    REQUIRE(GetFileAttributesW(paths[3]) == INVALID_FILE_ATTRIBUTES);
    // Submit a complete held Enter, including repeated key-downs and the final
    // release, before the launched console can become the keyboard target.
    INPUT enter[4] = {0};
    for (unsigned i = 0; i < ARRAYSIZE(enter); ++i) {
        enter[i].type = INPUT_KEYBOARD;
        enter[i].ki.wVk = VK_RETURN;
    }
    enter[3].ki.dwFlags = KEYEVENTF_KEYUP;
    send_events(enter, ARRAYSIZE(enter));
    wait_for_launches(1);
    activate_main();
    selected(0);
    key('O', true);
    wait_for_launches(2);
    activate_main();

    click(combo);
    key(VK_HOME, false);
    key(VK_RETURN, false);
    results(3);
    selected(-1);
    click(edit);
    key('A', true);
    type_text(L"win-native-missing");
    expect_text(edit, L"win-native-missing");
    results(0);
}

static HWND open_settings(void) {
    activate_main();
    key(VK_OEM_COMMA, true);
    HWND panel = find_window(L"#32770", L"Interface");
    REQUIRE(GetWindow(panel, GW_OWNER) == window);
    return panel;
}

static void close_panel(HWND panel) {
    click(control(panel, IDCANCEL, L"Button"));
    ULONGLONG deadline = GetTickCount64() + 5000;
    while (IsWindow(panel)) REQUIRE(retry(deadline));
    REQUIRE(IsWindowVisible(window));
}

typedef struct {
    COLORREF pixels[9 * 9];
} IconSample;

// Read the displayed image slot from the unselected first row. Leave the
// header, image edges and filename outside the sample.
static IconSample sample_icon(void) {
    RECT heading;
    REQUIRE(GetWindowRect(header, &heading));
    POINT origin = {heading.left, heading.bottom};
    REQUIRE(ScreenToClient(list, &origin));
    int side = MulDiv(32, (int)GetDpiForWindow(list), 96);
    REQUIRE(side > 0);
    HDC dc = GetDC(list);
    REQUIRE(dc);
    IconSample sample;
    for (int y = 1; y <= 9; ++y) {
        for (int x = 1; x <= 9; ++x) {
            COLORREF pixel = GetPixel(dc, origin.x + side * x / 10, origin.y + side * y / 10);
            REQUIRE(pixel != CLR_INVALID);
            sample.pixels[9 * (y - 1) + x - 1] = pixel;
        }
    }
    ReleaseDC(list, dc);
    return sample;
}

// Poll several rendered frames while asynchronous decoding or a preference
// change repaints the table. A stock icon must also have visible detail.
static IconSample expect_icon(COLORREF fixture_color, bool embedded) {
    ULONGLONG deadline = GetTickCount64() + 12000;
    unsigned stable = 0, colored, different;
    IconSample sample;
    do {
        sample = sample_icon();
        different = colored = 0;
        for (unsigned i = 0; i < ARRAYSIZE(sample.pixels); ++i) {
            if (sample.pixels[i] != sample.pixels[0]) ++different;
            unsigned x = i % 9, y = i / 9;
            if ((x == 2 || x == 4 || x == 6) && (y == 2 || y == 4 || y == 6) &&
                sample.pixels[i] == fixture_color) ++colored;
        }
        if (embedded ? colored == 9 : colored == 0 && different >= 3) {
            if (++stable == 5) return sample;
        } else {
            stable = 0;
        }
    } while (retry(deadline));
    fprintf(stderr, "Expected %s icon (COLORREF %08lx), saw center %08lx, %u/9 matching samples and %u varied pixels.\n",
            embedded ? "embedded" : "fallback", fixture_color, sample.pixels[40], colored, different);
    fail("list-view icon pixels");
    return (IconSample){0};
}

static void search_fixture(const WCHAR *query, int count) {
    click(edit);
    key('A', true);
    type_text(query);
    expect_text(edit, query);
    results(count);
    selected(-1);
}

static void panels(void) {
    search_fixture(L"green test icon.exe", 1);
    HWND settings = open_settings();
    HWND check = control(settings, 6104, L"Button");
    expect_text(check, L"Show EXE icons");
    expect_text(control(settings, 6105, L"Button"), L"Show AppImage icons");
    bool checked = message(check, BM_GETCHECK, 0, 0) == BST_CHECKED;
    close_panel(settings);
    expect_icon(RGB(0, 255, 0), checked);
    // Exercise both directions without starting a new query or replacing its row.
    for (int i = 0; i < 2; ++i) {
        settings = open_settings();
        check = control(settings, 6104, L"Button");
        click(check);
        checked = !checked;
        ULONGLONG deadline = GetTickCount64() + 5000;
        while ((message(check, BM_GETCHECK, 0, 0) == BST_CHECKED) != checked) REQUIRE(retry(deadline));
        close_panel(settings);
        expect_icon(RGB(0, 255, 0), checked);
    }
    activate_main();
    key(VK_F1, false);
    HWND help = find_window(L"#32770", L"Search syntax");
    REQUIRE(GetWindow(help, GW_OWNER) == window);
    REQUIRE(message(control(help, 6106, L"Edit"), WM_GETTEXTLENGTH, 0, 0) > 0);
    HWND reference = control(help, 6109, L"Button");
    REQUIRE(!IsWindowVisible(reference));
    click(control(help, 6107, L"Button"));
    ULONGLONG deadline = GetTickCount64() + 5000;
    while (!IsWindowVisible(reference)) REQUIRE(retry(deadline));
    close_panel(help);
}

static void wait_for_exit(void) {
    REQUIRE(WaitForSingleObject(app.hProcess, 10000) == WAIT_OBJECT_0);
    DWORD code;
    REQUIRE(GetExitCodeProcess(app.hProcess, &code) && code == 0);
    CloseHandle(app.hProcess);
    app.hProcess = NULL;
}

static void bind_window(void) {
    window = find_window(L"DrillSearchWindow", L"Drill");
    edit = control(window, 101, L"Edit");
    combo = control(window, 102, L"ComboBox");
    list = control(window, 103, WC_LISTVIEWW);
    status = control(window, 104, L"Static");
    header = (HWND)message(list, LVM_GETHEADER, 0, 0);
    REQUIRE(header && message(header, HDM_GETITEMCOUNT, 0, 0) == 4);
    activate_main();
}

static void check_first_bundle(const WCHAR *directory, const WCHAR *name, COLORREF color) {
    WCHAR expected[MAX_PATH];
    int n = swprintf(expected, ARRAYSIZE(expected), L"%ls\\%ls", directory, name);
    REQUIRE(n > 0 && (size_t)n < ARRAYSIZE(expected));
    // Also put a real row click between header clicks. Without this, the OS
    // can turn two quick sorts into one header click and one double-click.
    click_point(list, first_row());
    selected(0);
    copy_and_expect(expected);
    key(VK_UP, false);
    selected(-1);
    expect_icon(color, true);
}

static void bundle_icons(const WCHAR *executable) {
    WCHAR directory[MAX_PATH];
    DWORD length = GetFullPathNameW(L"tests\\native_ui\\fixtures\\mac-bundles", ARRAYSIZE(directory), directory, NULL);
    REQUIRE(length && length < ARRAYSIZE(directory));
    launch(executable, directory, !use_msaa);
    bind_window();
    // Both bundles coexist in one result set. Sorting reverses which bundle
    // occupies the first row, including when the image list already has icons.
    search_fixture(L"regex:^(Carmine|Jade)\\.app$", 2);
    click(header);
    check_first_bundle(directory, L"Carmine.app", RGB(255, 0, 0));
    click(header);
    check_first_bundle(directory, L"Jade.app", RGB(0, 255, 0));
    search_fixture(L"Missing.app", 1);
    IconSample application = expect_icon(CLR_INVALID, false);
    search_fixture(L"Contents", 3);
    IconSample folder = expect_icon(CLR_INVALID, false);
    REQUIRE(memcmp(&application, &folder, sizeof(folder)) != 0);
    message(window, WM_CLOSE, 0, 0);
    wait_for_exit();
}

static void wait_for_bounds(const RECT *bounds) {
    RECT actual = {0};
    ULONGLONG deadline = GetTickCount64() + 5000;
    do {
        REQUIRE(GetWindowRect(window, &actual));
        if (!IsZoomed(window) && labs(actual.left - bounds->left) <= 1 &&
            labs(actual.top - bounds->top) <= 1 && labs(actual.right - bounds->right) <= 1 &&
            labs(actual.bottom - bounds->bottom) <= 1) return;
    } while (retry(deadline));
    fprintf(stderr, "Expected normal bounds (%ld,%ld,%ld,%ld), got (%ld,%ld,%ld,%ld), zoomed=%d\n",
            bounds->left, bounds->top, bounds->right, bounds->bottom,
            actual.left, actual.top, actual.right, actual.bottom, IsZoomed(window));
    fail("restoring window placement");
}

static void wait_for_maximized(void) {
    ULONGLONG deadline = GetTickCount64() + 5000;
    while (!IsZoomed(window)) REQUIRE(retry(deadline));
}

static void check_geometry(const WCHAR *executable) {
    message(window, WM_SYSCOMMAND, SC_RESTORE, 0);
    MONITORINFO monitor = {0};
    monitor.cbSize = sizeof(monitor);
    REQUIRE(GetMonitorInfoW(MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST), &monitor));
    RECT work = monitor.rcWork;
    LONG width = (work.right - work.left) * 3 / 4, height = (work.bottom - work.top) * 3 / 4;
    RECT normal = {work.left + 29, work.top + 21, work.left + 29 + width, work.top + 21 + height};
    REQUIRE(SetWindowPos(window, NULL, normal.left, normal.top, width, height,
                         SWP_NOACTIVATE | SWP_NOZORDER));
    wait_for_bounds(&normal);
    click(edit);
    key(VK_ESCAPE, false);
    wait_for_exit();

    launch(executable, root, false);
    window = find_window(L"DrillSearchWindow", L"Drill");
    wait_for_bounds(&normal);
    message(window, WM_SYSCOMMAND, SC_MAXIMIZE, 0);
    wait_for_maximized();
    message(window, WM_CLOSE, 0, 0);
    wait_for_exit();

    launch(executable, root, false);
    window = find_window(L"DrillSearchWindow", L"Drill");
    wait_for_maximized();
    message(window, WM_SYSCOMMAND, SC_RESTORE, 0);
    wait_for_bounds(&normal);
    message(window, WM_CLOSE, 0, 0);
    wait_for_exit();
}

int wmain(int argc, WCHAR **argv) {
    WCHAR self[MAX_PATH];
    DWORD n = GetModuleFileNameW(NULL, self, ARRAYSIZE(self));
    REQUIRE(n && n < ARRAYSIZE(self));
    WCHAR *name = wcsrchr(self, L'\\');
    if (argc == 1 && name && _wcsicmp(name + 1, files[2]) == 0) {
        REQUIRE(GetEnvironmentVariableW(bridge_marker, NULL, 0) == 0);
        // Let Windows release the fixture console before reporting that Open ran.
        FreeConsole();
        lstrcpyW(name + 1, files[3]);
        HANDLE marker = CreateFileW(self, FILE_APPEND_DATA, FILE_SHARE_READ | FILE_SHARE_WRITE, NULL,
                                    OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
        REQUIRE(marker != INVALID_HANDLE_VALUE);
        DWORD written = 0;
        REQUIRE(WriteFile(marker, "1", 1, &written, NULL) && written == 1);
        CloseHandle(marker);
        return 0;
    }
    use_msaa = !(argc == 3 && wcscmp(argv[2], L"--wine") == 0);
    if (argc != 2 && use_msaa) {
        fputs("Usage on a controlled desktop: drill-native-window.exe <path-to-Drill.exe>\n", stderr);
        return 2;
    }
    if (use_msaa) {
        REQUIRE(SUCCEEDED(CoInitializeEx(NULL, COINIT_APARTMENTTHREADED)));
    } else {
        reserve_bridge();
    }
    // Keep hit-test coordinates in physical pixels on scaled displays.
    SetProcessDPIAware();
    atexit(clean_up);
    preserve_value(L"Software\\Drill\\Interface", L"WindowPlacement");
    preserve_value(L"Software\\Drill\\Interface", L"ShowExeIcons");
    fixture(self);
    launch(argv[1], root, false);
    bind_window();
    REQUIRE(message(combo, CB_GETCOUNT, 0, 0) == 2 && message(combo, CB_GETCURSEL, 0, 0) == 0);
    expect_text(status, L"Type to search");
    REQUIRE(!IsWindowEnabled(control(window, 105, L"Button")));
    REQUIRE(!IsWindowVisible(control(window, 106, L"Button")));
    stage = "typing and sorting";
    search_and_sort();
    stage = "filtering and launching";
    filter_and_launch();
    stage = "settings and icon rendering";
    panels();
    stage = "restoring window geometry";
    check_geometry(argv[1]);
    REQUIRE(launches() == 2);
    stage = "displaying macOS bundle icons";
    bundle_icons(argv[1]);
    if (use_msaa) CoUninitialize();
    fputs("Native Windows search, selection, clipboard, sorting, launch shortcuts, panels, geometry and bundle icons passed.\n",
          use_msaa ? stdout : stderr);
    return 0;
}
