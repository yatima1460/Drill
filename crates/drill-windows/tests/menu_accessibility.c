#define COBJMACROS
#include <windows.h>
#include <oleacc.h>
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
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

static void check_accessible_names(HWND window) {
    IAccessible *bar = NULL;
    HRESULT result = AccessibleObjectFromWindow(window, OBJID_MENU, &IID_IAccessible, (void **)&bar);
    if (result != S_OK) {
        fprintf(stderr, "AccessibleObjectFromWindow(OBJID_MENU) returned 0x%08lx\n", (unsigned long)result);
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

int main(int argc, char **argv) {
    // Wine lacks OBJID_MENU; on native Windows the provider check runs by default.
    bool metadata_only = argc == 2 && strcmp(argv[1], "--metadata-only") == 0;
    assert(argc == 1 || metadata_only);
    assert(SUCCEEDED(CoInitializeEx(NULL, COINIT_APARTMENTTHREADED)));
    HWND window = CreateWindowExW(WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE, L"STATIC", L"Drill menu test",
                                 WS_OVERLAPPEDWINDOW, -30000, -30000, 400, 180,
                                 NULL, NULL, NULL, NULL);
    assert(window);
    ShowWindow(window, SW_SHOWNOACTIVATE);
    void *menu = drill_windows_menu_install(window, unused_command, NULL);
    assert(menu);
    HIGHCONTRASTW contrast = {0};
    contrast.cbSize = sizeof(contrast);
    bool can_draw_dark = SystemParametersInfoW(SPI_GETHIGHCONTRAST, sizeof(contrast), &contrast, 0)
        && !(contrast.dwFlags & HCF_HIGHCONTRASTON);
    puts(can_draw_dark ? "Checking owner-drawn dark menu presentation."
                       : "Checking system menu presentation with dark rendering unavailable.");
    for (unsigned stage = 0; stage < 3; ++stage) {
        bool dark = stage == 1;
        drill_windows_menu_set_dark(menu, dark);
        check_appearance(window, dark && can_draw_dark);
        if (!metadata_only) {
            check_accessible_names(window);
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
    CoUninitialize();
    puts(metadata_only ? "Menu metadata and keyboard checks passed."
                       : "Native menu accessible names and keyboard checks passed.");
    return 0;
}
