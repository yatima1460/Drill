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
#include <wchar.h>

static bool use_msaa = true;
static PROCESS_INFORMATION app;
static HWND window, edit, combo, list, header, status;
static WCHAR root[MAX_PATH];
static const WCHAR *const files[] = {
    L"win-native-a-\U0001F9EA.txt", L"win-native-z.txt", L"win-native-m.exe", L"opened.marker"
};
static WCHAR paths[ARRAYSIZE(files)][MAX_PATH];

static void fail(const char *message) {
    fprintf(stderr, "Native window test failed: %s (Win32 error %lu)\n", message, GetLastError());
    exit(1);
}
#define REQUIRE(test) do { if (!(test)) fail(#test); } while (0)

static void clean_up(void) {
    if (app.hProcess) {
        if (WaitForSingleObject(app.hProcess, 0) == WAIT_TIMEOUT) {
            TerminateProcess(app.hProcess, 1);
            WaitForSingleObject(app.hProcess, 5000);
        }
        CloseHandle(app.hProcess);
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
}

static void launch(const WCHAR *path) {
    WCHAR executable[MAX_PATH], command[2 * MAX_PATH + 32];
    DWORD n = GetFullPathNameW(path, ARRAYSIZE(executable), executable, NULL);
    REQUIRE(n && n < ARRAYSIZE(executable));
    int chars = swprintf(command, ARRAYSIZE(command), L"\"%ls\" --root \"%ls\"", executable, root);
    REQUIRE(chars > 0 && (size_t)chars < ARRAYSIZE(command));
    STARTUPINFOW startup = {0};
    startup.cb = sizeof(startup);
    REQUIRE(CreateProcessW(executable, command, NULL, NULL, FALSE, 0, NULL, NULL, &startup, &app));
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
    HWND hit = WindowFromPoint(point);
    REQUIRE(hit == target || IsChild(target, hit));
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
        if (code == VK_UP || code == VK_DOWN || code == VK_RIGHT || code == VK_HOME || code == VK_END) {
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

    click(edit);
    GUITHREADINFO focus = {0};
    focus.cbSize = sizeof(focus);
    ULONGLONG deadline = GetTickCount64() + 5000;
    do {
        REQUIRE(GetGUIThreadInfo(app.dwThreadId, &focus));
        if (focus.hwndFocus == edit) break;
        REQUIRE(retry(deadline));
    } while (true);
    message(edit, EM_SETSEL, 0, 10);
    copy_and_expect(L"win-native");
    key('A', true);
    key('V', true);
    expect_text(edit, L"win-native");
    results(3);
    selected(-1);
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
    key(VK_RETURN, false);
    ULONGLONG deadline = GetTickCount64() + 10000;
    while (GetFileAttributesW(paths[3]) == INVALID_FILE_ATTRIBUTES) {
        REQUIRE(retry(deadline));
    }
    // The fixture process may briefly own focus while its console closes.
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

static HWND open_panel(int menu_index, const WCHAR *title) {
    // An HMENU from a different process is not a portable inspection handle
    // under Wine. Use the visible menu bar's ordinary keyboard navigation.
    activate_main();
    key(VK_F10, false);
    key(VK_HOME, false);
    for (int i = 0; i < menu_index; ++i) key(VK_RIGHT, false);
    key(VK_DOWN, false);
    key(VK_RETURN, false);
    HWND panel = find_window(L"#32770", title);
    REQUIRE(GetWindow(panel, GW_OWNER) == window);
    return panel;
}

static void close_panel(HWND panel) {
    click(control(panel, IDCANCEL, L"Button"));
    ULONGLONG deadline = GetTickCount64() + 5000;
    while (IsWindow(panel)) REQUIRE(retry(deadline));
    REQUIRE(IsWindowVisible(window));
}

static void panels(void) {
    HWND settings = open_panel(1, L"Interface");
    expect_text(control(settings, 6104, L"Button"), L"Show EXE icons");
    expect_text(control(settings, 6105, L"Button"), L"Show AppImage icons");
    close_panel(settings);
    HWND help = open_panel(2, L"Search syntax");
    REQUIRE(message(control(help, 6106, L"Edit"), WM_GETTEXTLENGTH, 0, 0) > 0);
    HWND reference = control(help, 6109, L"Button");
    REQUIRE(!IsWindowVisible(reference));
    click(control(help, 6107, L"Button"));
    ULONGLONG deadline = GetTickCount64() + 5000;
    while (!IsWindowVisible(reference)) REQUIRE(retry(deadline));
    close_panel(help);
}

int wmain(int argc, WCHAR **argv) {
    WCHAR self[MAX_PATH];
    DWORD n = GetModuleFileNameW(NULL, self, ARRAYSIZE(self));
    REQUIRE(n && n < ARRAYSIZE(self));
    WCHAR *name = wcsrchr(self, L'\\');
    if (argc == 1 && name && _wcsicmp(name + 1, files[2]) == 0) {
        // Let Windows release the fixture console before reporting that Open ran.
        FreeConsole();
        lstrcpyW(name + 1, files[3]);
        create_file(self);
        return 0;
    }
    use_msaa = !(argc == 3 && wcscmp(argv[2], L"--wine") == 0);
    if (argc != 2 && use_msaa) {
        fputs("Usage on a controlled desktop: drill-native-window.exe <path-to-Drill.exe>\n", stderr);
        return 2;
    }
    if (use_msaa) REQUIRE(SUCCEEDED(CoInitializeEx(NULL, COINIT_APARTMENTTHREADED)));
    // Keep hit-test coordinates in physical pixels on scaled displays.
    SetProcessDPIAware();
    atexit(clean_up);
    fixture(self);
    launch(argv[1]);
    window = find_window(L"DrillSearchWindow", L"Drill");
    edit = control(window, 101, L"Edit");
    combo = control(window, 102, L"ComboBox");
    list = control(window, 103, WC_LISTVIEWW);
    status = control(window, 104, L"Static");
    header = (HWND)message(list, LVM_GETHEADER, 0, 0);
    REQUIRE(header && message(header, HDM_GETITEMCOUNT, 0, 0) == 4);
    REQUIRE(message(combo, CB_GETCOUNT, 0, 0) == 2 && message(combo, CB_GETCURSEL, 0, 0) == 0);
    activate_main();
    expect_text(status, L"Type to search");
    REQUIRE(!IsWindowEnabled(control(window, 105, L"Button")));
    REQUIRE(!IsWindowVisible(control(window, 106, L"Button")));
    search_and_sort();
    filter_and_launch();
    panels();
    click(edit);
    key(VK_ESCAPE, false);
    REQUIRE(WaitForSingleObject(app.hProcess, 10000) == WAIT_OBJECT_0);
    DWORD code;
    REQUIRE(GetExitCodeProcess(app.hProcess, &code) && code == 0);
    if (use_msaa) CoUninitialize();
    puts("Native Windows search, selection, clipboard, sorting, launch, panels and Escape passed.");
    return 0;
}
