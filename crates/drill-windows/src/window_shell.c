// Paths used by these explicit user actions are owned, NUL-terminated UTF-16.
#include <windows.h>
#include <shellapi.h>
#include <shlobj.h>
#include <stdlib.h>
#include <wchar.h>

static HRESULT win_last_failure(void) {
    DWORD error = GetLastError();
    return error ? HRESULT_FROM_WIN32(error) : E_FAIL;
}

static void win_action_error(HWND owner, HRESULT error, const WCHAR *title) {
    if (SUCCEEDED(error) || error == HRESULT_FROM_WIN32(ERROR_CANCELLED) || !IsWindow(owner)) return;
    WCHAR message[1024];
    DWORD code = HRESULT_FACILITY(error) == FACILITY_WIN32 ? HRESULT_CODE(error) : (DWORD)error;
    if (!FormatMessageW(FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS, NULL,
                        code, 0, message, ARRAYSIZE(message), NULL)) {
        swprintf(message, ARRAYSIZE(message), L"Windows returned error 0x%08lX.", (unsigned long)error);
    }
    MessageBoxW(owner, message, title, MB_OK | MB_ICONERROR);
}

static HRESULT win_open_item(HWND owner, const WCHAR *path) {
    SHELLEXECUTEINFOW info = {0};
    info.cbSize = sizeof(info);
    info.fMask = SEE_MASK_FLAG_NO_UI;
    info.hwnd = owner;
    info.lpFile = path;
    info.nShow = SW_SHOWNORMAL;
    return ShellExecuteExW(&info) ? S_OK : win_last_failure();
}

static HRESULT win_show_in_explorer(const WCHAR *path) {
    PIDLIST_ABSOLUTE item = NULL;
    HRESULT result = SHParseDisplayName(path, NULL, &item, 0, NULL);
    if (SUCCEEDED(result)) {
        // A fully qualified PIDL and a zero count select one item in its parent.
        result = SHOpenFolderAndSelectItems(item, 0, NULL, 0);
        CoTaskMemFree(item);
    }
    return result;
}

static WCHAR *win_system_file(const WCHAR *suffix) {
    UINT capacity = GetSystemDirectoryW(NULL, 0);
    if (!capacity) return NULL;
    WCHAR *path = malloc((capacity + wcslen(suffix)) * sizeof(*path));
    if (path) {
        UINT used = GetSystemDirectoryW(path, capacity);
        if (used > 0 && used < capacity) {
            wcscpy(path + used, suffix);
        } else {
            free(path);
            path = NULL;
        }
    }
    return path;
}

static HRESULT win_spawn_terminal(const WCHAR *exe, WCHAR *command, const WCHAR *directory) {
    if (!exe) return HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND);
    STARTUPINFOW startup = {0};
    PROCESS_INFORMATION child = {0};
    startup.cb = sizeof(startup);
    if (!CreateProcessW(exe, command, NULL, NULL, FALSE, CREATE_NEW_CONSOLE,
                        NULL, directory, &startup, &child)) return win_last_failure();
    CloseHandle(child.hThread);
    CloseHandle(child.hProcess);
    return S_OK;
}

static HRESULT win_terminal_here(WCHAR *path, bool directory) {
    DWORD attributes = GetFileAttributesW(path);
    if (!directory && (attributes == INVALID_FILE_ATTRIBUTES || !(attributes & FILE_ATTRIBUTE_DIRECTORY))) {
        WCHAR *last = NULL;
        for (WCHAR *p = path; *p; ++p) {
            if (*p == L'\\' || *p == L'/') last = p;
        }
        if (!last) return HRESULT_FROM_WIN32(ERROR_DIRECTORY);
        last[1] = 0; // Keep the separator, including for a file in a drive root.
    }
    attributes = GetFileAttributesW(path);
    if (attributes == INVALID_FILE_ATTRIBUTES) return win_last_failure();
    if (!(attributes & FILE_ATTRIBUTE_DIRECTORY)) return HRESULT_FROM_WIN32(ERROR_DIRECTORY);

    // Resolve known OS programs explicitly. Put the discovered path only in
    // lpCurrentDirectory, never in the shell command line or executable search.
    WCHAR *terminal = win_known_file(&FOLDERID_LocalAppData, L"\\Microsoft\\WindowsApps\\wt.exe");
    WCHAR tab[] = L"wt.exe new-tab -d .";
    HRESULT result = win_spawn_terminal(terminal, tab, path);
    free(terminal);
    if (result == HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND) || result == HRESULT_FROM_WIN32(ERROR_PATH_NOT_FOUND)) {
        WCHAR *powershell = win_system_file(L"\\WindowsPowerShell\\v1.0\\powershell.exe");
        WCHAR prompt[] = L"powershell.exe -NoLogo -NoProfile";
        result = win_spawn_terminal(powershell, prompt, path);
        free(powershell);
    }
    if (result == HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND) || result == HRESULT_FROM_WIN32(ERROR_PATH_NOT_FOUND)) {
        WCHAR *cmd = win_system_file(L"\\cmd.exe");
        WCHAR prompt[] = L"cmd.exe /D";
        result = win_spawn_terminal(cmd, prompt, path);
        free(cmd);
    }
    return result;
}

static HBITMAP win_menu_icon(HICON icon, int size) {
    if (!icon) return NULL;
    BITMAPINFO info = {0};
    info.bmiHeader.biSize = sizeof(info.bmiHeader);
    info.bmiHeader.biWidth = size;
    info.bmiHeader.biHeight = -size;
    info.bmiHeader.biPlanes = 1;
    info.bmiHeader.biBitCount = 32;
    info.bmiHeader.biCompression = BI_RGB;
    uint32_t *pixels = NULL;
    HDC dc = CreateCompatibleDC(NULL);
    HBITMAP bitmap = dc ? CreateDIBSection(dc, &info, DIB_RGB_COLORS, (void **)&pixels, NULL, 0) : NULL;
    if (bitmap) {
        HGDIOBJ previous = SelectObject(dc, bitmap);
        memset(pixels, 0, size * size * sizeof(*pixels));
        DrawIconEx(dc, 0, 0, icon, size, size, 0, NULL, DI_NORMAL);
        GdiFlush();
        bool alpha = false;
        for (int i = 0; i < size * size; ++i) alpha |= (pixels[i] >> 24) != 0;
        if (!alpha) { // Classic masked icons lack an alpha channel.
            RECT rect = {0, 0, size, size};
            FillRect(dc, &rect, GetSysColorBrush(COLOR_MENU));
            DrawIconEx(dc, 0, 0, icon, size, size, 0, NULL, DI_NORMAL);
            GdiFlush();
            for (int i = 0; i < size * size; ++i) pixels[i] |= 0xff000000u;
        }
        SelectObject(dc, previous);
    }
    if (dc) DeleteDC(dc);
    DestroyIcon(icon);
    return bitmap;
}

static void win_context_images(HWND owner, HMENU menu, HBITMAP images[2], UINT reveal, UINT terminal) {
    UINT dpi = GetDpiForWindow(owner);
    int size = GetSystemMetricsForDpi(SM_CXSMICON, dpi ? dpi : 96);
    if (size <= 0 || size > 256) size = 16;
    SHSTOCKICONINFO stock = {0};
    stock.cbSize = sizeof(stock);
    if (SUCCEEDED(SHGetStockIconInfo(SIID_FOLDEROPEN, SHGSI_ICON | SHGSI_SMALLICON, &stock))) {
        images[0] = win_menu_icon(stock.hIcon, size);
    }
    // Extract only from the console shipped with Windows, never from a result.
    WCHAR *cmd = win_system_file(L"\\cmd.exe");
    HICON icon = NULL;
    if (cmd) {
        ExtractIconExW(cmd, 0, NULL, &icon, 1);
        free(cmd);
    }
    images[1] = win_menu_icon(icon, size);
    for (int i = 0; i < 2; ++i) {
        if (!images[i]) continue;
        MENUITEMINFOW item = {0};
        item.cbSize = sizeof(item);
        item.fMask = MIIM_BITMAP;
        item.hbmpItem = images[i];
        SetMenuItemInfoW(menu, i == 0 ? reveal : terminal, FALSE, &item);
    }
}
