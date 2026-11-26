#define COBJMACROS
#include <windows.h>
#include <oleacc.h>
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

void *drill_windows_menu_install(HWND, void (*)(const void *, uint8_t), const void *);
void drill_windows_menu_set_dark(void *, bool);
void drill_windows_menu_set_enabled(void *, bool, bool);
void drill_windows_menu_remove(void *);

static const WCHAR *const titles[] = { L"Search", L"Settings", L"Help" };

static void unused_command(const void *context, uint8_t command) {
    (void)context;
    (void)command;
}

// Microsoft Active Accessibility represents children as either IDs or dispatch objects.
static BSTR accessible_name(IAccessible *bar, VARIANT child) {
    BSTR name = NULL;
    if (child.vt == VT_I4) {
        assert(IAccessible_get_accName(bar, child, &name) == S_OK);
    } else {
        IAccessible *item = NULL;
        assert(child.vt == VT_DISPATCH && child.pdispVal);
        assert(IDispatch_QueryInterface(child.pdispVal, &IID_IAccessible, (void **)&item) == S_OK);
        VARIANT self = { .vt = VT_I4 };
        self.lVal = CHILDID_SELF;
        assert(IAccessible_get_accName(item, self, &name) == S_OK);
        IAccessible_Release(item);
    }
    return name;
}

// Some provider configurations do not expose the menu bar by its object ID. An
// assistive client can also hit-test the visible headings through MSAA itself.
static void check_names_at_points(HWND window) {
    for (UINT i = 0; i < ARRAYSIZE(titles); ++i) {
        MENUBARINFO bounds = {0};
        bounds.cbSize = sizeof(bounds);
        assert(GetMenuBarInfo(window, OBJID_MENU, (LONG)i + 1, &bounds));
        assert(!IsRectEmpty(&bounds.rcBar));
        POINT center = { bounds.rcBar.left + (bounds.rcBar.right - bounds.rcBar.left) / 2,
                         bounds.rcBar.top + (bounds.rcBar.bottom - bounds.rcBar.top) / 2 };
        assert(GetAncestor(WindowFromPoint(center), GA_ROOT) == window);
        IAccessible *owner = NULL;
        VARIANT child = {0}, role = {0};
        HRESULT result = AccessibleObjectFromPoint(center, &owner, &child);
        if (result != S_OK) {
            fprintf(stderr, "AccessibleObjectFromPoint returned 0x%08lx at item %u\n",
                    (unsigned long)result, i);
        }
        assert(result == S_OK && owner);
        assert(IAccessible_get_accRole(owner, child, &role) == S_OK);
        assert(role.vt == VT_I4 && role.lVal == ROLE_SYSTEM_MENUITEM);
        BSTR name = NULL;
        assert(IAccessible_get_accName(owner, child, &name) == S_OK);
        if (!name || wcscmp(name, titles[i]) != 0) {
            fwprintf(stderr, L"Hit-tested menu item %u: expected %ls, got %ls\n",
                     i, titles[i], name ? name : L"(null)");
            exit(1);
        }
        SysFreeString(name);
        VariantClear(&role);
        VariantClear(&child);
        IAccessible_Release(owner);
    }
}

static void check_accessible_names(HWND window) {
    MENUBARINFO bounds = {0};
    bounds.cbSize = sizeof(bounds);
    assert(GetMenuBarInfo(window, OBJID_MENU, 0, &bounds) && bounds.hMenu);
    assert(!IsRectEmpty(&bounds.rcBar) && MonitorFromRect(&bounds.rcBar, MONITOR_DEFAULTTONULL));
    IAccessible *bar = NULL;
    HRESULT result = AccessibleObjectFromWindow(window, OBJID_MENU, &IID_IAccessible, (void **)&bar);
    if (result != S_OK) {
        fprintf(stderr, "AccessibleObjectFromWindow(OBJID_MENU) returned 0x%08lx\n", (unsigned long)result);
    }
    if (result == E_NOINTERFACE) {
        fputs("Reading the three native menu item roles and names through MSAA hit-testing.\n", stderr);
        check_names_at_points(window);
        return;
    }
    assert(result == S_OK && bar);
    VARIANT items[ARRAYSIZE(titles)] = {0};
    long count = 0;
    assert(AccessibleChildren(bar, 0, ARRAYSIZE(items), items, &count) == S_OK);
    assert(count == ARRAYSIZE(titles));
    for (long i = 0; i < count; ++i) {
        BSTR name = accessible_name(bar, items[i]);
        if (!name || wcscmp(name, titles[i]) != 0) {
            fwprintf(stderr, L"Menu item %ld: expected %ls, got %ls\n", i, titles[i], name ? name : L"(null)");
            exit(1);
        }
        SysFreeString(name);
        VariantClear(&items[i]);
    }
    IAccessible_Release(bar);
}

static void check_appearance(HWND window, bool owner_drawn) {
    HMENU bar = GetMenu(window);
    for (UINT i = 0; i < ARRAYSIZE(titles); ++i) {
        MENUITEMINFOW item = {0};
        item.cbSize = sizeof(item);
        item.fMask = MIIM_FTYPE | MIIM_DATA;
        assert(GetMenuItemInfoW(bar, i, TRUE, &item));
        assert(((item.fType & MFT_OWNERDRAW) != 0) == owner_drawn);
        if (owner_drawn) {
            const MSAAMENUINFO *label = (const MSAAMENUINFO *)item.dwItemData;
            assert(label && label->dwMSAASignature == MSAA_MENU_SIG);
            assert(label->cchWText == wcslen(titles[i]) && wcscmp(label->pszWText, titles[i]) == 0);
        } else {
            WCHAR name[16];
            assert(GetMenuStringW(bar, i, name, ARRAYSIZE(name), MF_BYPOSITION) > 0);
            assert(wcscmp(name, titles[i]) == 0);
        }
    }
}

// The assistive client runs in its own process, while the owner dispatches WM_GETOBJECT.
static void check_from_client(HWND window) {
    WCHAR executable[MAX_PATH], args[80];
    DWORD length = GetModuleFileNameW(NULL, executable, ARRAYSIZE(executable));
    assert(length > 0 && length < ARRAYSIZE(executable));
    swprintf(args, ARRAYSIZE(args), L"drill-menu-accessibility --read %llu",
             (unsigned long long)(uintptr_t)window);
    STARTUPINFOW startup = {0};
    startup.cb = sizeof(startup);
    PROCESS_INFORMATION client = {0};
    assert(CreateProcessW(executable, args, NULL, NULL, FALSE, 0, NULL, NULL, &startup, &client));
    CloseHandle(client.hThread);
    ULONGLONG deadline = GetTickCount64() + 15000;
    for (;;) {
        ULONGLONG now = GetTickCount64();
        if (now >= deadline) {
            TerminateProcess(client.hProcess, 1);
            fputs("Timed out waiting for the accessibility client.\n", stderr);
            exit(1);
        }
        DWORD ready = MsgWaitForMultipleObjectsEx(1, &client.hProcess, (DWORD)(deadline - now),
                                                  QS_ALLINPUT, MWMO_INPUTAVAILABLE);
        if (ready == WAIT_OBJECT_0) break;
        assert(ready == WAIT_OBJECT_0 + 1 || ready == WAIT_TIMEOUT);
        MSG msg;
        while (PeekMessageW(&msg, NULL, 0, 0, PM_REMOVE)) {
            TranslateMessage(&msg);
            DispatchMessageW(&msg);
        }
    }
    DWORD status;
    assert(GetExitCodeProcess(client.hProcess, &status));
    CloseHandle(client.hProcess);
    assert(status == 0);
}

static HMENU stock_menu(void) {
    HMENU bar = CreateMenu();
    assert(bar);
    for (size_t i = 0; i < ARRAYSIZE(titles); ++i) {
        HMENU popup = CreatePopupMenu();
        assert(popup && AppendMenuW(popup, MF_STRING, 1 + i, L"Command"));
        assert(AppendMenuW(bar, MF_POPUP, (UINT_PTR)popup, titles[i]));
    }
    return bar;
}

int main(int argc, char **argv) {
    if (argc == 3 && strcmp(argv[1], "--read") == 0) {
        HWND target = (HWND)(uintptr_t)strtoull(argv[2], NULL, 10);
        assert(IsWindow(target));
        assert(SUCCEEDED(CoInitializeEx(NULL, COINIT_APARTMENTTHREADED)));
        check_accessible_names(target);
        CoUninitialize();
        return 0;
    }
    // Wine lacks OBJID_MENU; the native Windows job always runs the external reader.
    bool metadata_only = argc == 2 && strcmp(argv[1], "--metadata-only") == 0;
    assert(argc == 1 || metadata_only);
    WNDCLASSW window_class = {0};
    window_class.hInstance = GetModuleHandleW(NULL);
    window_class.lpfnWndProc = DefWindowProcW;
    window_class.lpszClassName = L"DrillMenuAccessibilityTest";
    assert(RegisterClassW(&window_class));
    HWND window = CreateWindowExW(0, window_class.lpszClassName, L"Drill menu test",
                                  WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT, 640, 360,
                                  NULL, stock_menu(), window_class.hInstance, NULL);
    assert(window);
    ShowWindow(window, metadata_only ? SW_SHOWNOACTIVATE : SW_SHOW);
    UpdateWindow(window);
    if (!metadata_only) {
        fprintf(stderr, "Checking stock menu through the Windows accessibility provider.\n");
        check_from_client(window);
    }
    void *menu = drill_windows_menu_install(window, unused_command, NULL);
    assert(menu && DrawMenuBar(window));
    HIGHCONTRASTW contrast = {0};
    contrast.cbSize = sizeof(contrast);
    assert(SystemParametersInfoW(SPI_GETHIGHCONTRAST, sizeof(contrast), &contrast, 0));
    bool can_draw_dark = !(contrast.dwFlags & HCF_HIGHCONTRASTON);
    for (unsigned stage = 0; stage < 3; ++stage) {
        bool dark = stage == 1;
        fprintf(stderr, "Checking Drill stage %u (%s).\n", stage,
                dark && can_draw_dark ? "owner-drawn dark" : "system strings");
        drill_windows_menu_set_dark(menu, dark);
        check_appearance(window, dark && can_draw_dark);
        if (!metadata_only) {
            check_from_client(window);
        }
        if (dark && can_draw_dark) {
            LPARAM bar = (LPARAM)GetMenu(window);
            assert(SendMessageW(window, WM_MENUCHAR, 'H', bar) == MAKELRESULT(2, MNC_EXECUTE));
            assert(SendMessageW(window, WM_MENUCHAR, 's', bar) == MAKELRESULT(0, MNC_SELECT));
            drill_windows_menu_set_enabled(menu, false, false);
            assert(SendMessageW(window, WM_MENUCHAR, 'S', bar) == MAKELRESULT(0, MNC_EXECUTE));
        }
    }
    drill_windows_menu_remove(menu);
    DestroyWindow(window);
    puts(metadata_only ? "Menu metadata and keyboard checks passed."
                       : "Native menu accessible names and keyboard checks passed.");
    return 0;
}
