#include <windows.h>
#include <string.h>
#include <wchar.h>

// The test opens this executable through Drill's real shell action. Link the
// Windows subsystem and create no windows so it cannot steal input focus.
int WINAPI wWinMain(HINSTANCE instance, HINSTANCE previous, LPWSTR command, int show) {
    (void)instance;
    (void)previous;
    (void)show;
    if (*command || GetEnvironmentVariableW(L"DRILL_WINE_BUNDLE_PIPE", NULL, 0)) return 1;

    WCHAR path[MAX_PATH];
    DWORD length = GetModuleFileNameW(NULL, path, ARRAYSIZE(path));
    if (!length || length >= ARRAYSIZE(path)) return 1;
    WCHAR *base = wcsrchr(path, L'\\');
    static const WCHAR name[] = L"opened.marker";
    if (!base || (size_t)(base + 1 - path) + ARRAYSIZE(name) > ARRAYSIZE(path)) return 1;
    memcpy(base + 1, name, sizeof(name));

    HANDLE marker = CreateFileW(path, FILE_APPEND_DATA, FILE_SHARE_READ | FILE_SHARE_WRITE, NULL,
                                OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    if (marker == INVALID_HANDLE_VALUE) return 1;
    DWORD written = 0;
    BOOL recorded = WriteFile(marker, "1", 1, &written, NULL);
    CloseHandle(marker);
    return recorded && written == 1 ? 0 : 1;
}
