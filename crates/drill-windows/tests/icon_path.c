// Exercise the sharing contract on a private file and folder. No Shell handler
// or discovered application is invoked by this test.
#include "../src/window_icon_path.h"
#include <stdio.h>

static bool test_pins(const WCHAR *folder, const WCHAR *file) {
    const DWORD share = FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE;
    HANDLE writer = CreateFileW(file, GENERIC_WRITE, share, NULL, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, NULL);
    if (writer == INVALID_HANDLE_VALUE) return false;
    DrillPinnedIcon pin = {0};
    bool pinned = pin_icon_path(file, false, &pin);
    CloseHandle(writer);
    if (pinned) {
        unpin_icon_path(&pin);
        fputs("Expected a type fallback for a file open for writing.\n", stderr);
        return false;
    }

    // A shared reader is compatible. An open folder with delete access is not.
    HANDLE reader = CreateFileW(file, GENERIC_READ, share, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    if (reader == INVALID_HANDLE_VALUE) return false;
    pinned = pin_icon_path(file, false, &pin);
    bool stable = pinned && wcsncmp(pin.path, L"\\\\?\\Volume{", 11) == 0;
    if (pinned) {
        writer = CreateFileW(file, GENERIC_WRITE, share, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
        stable = stable && writer == INVALID_HANDLE_VALUE && GetLastError() == ERROR_SHARING_VIOLATION;
        if (writer != INVALID_HANDLE_VALUE) CloseHandle(writer);
        unpin_icon_path(&pin);
    }
    CloseHandle(reader);
    if (!stable) {
        fputs("Expected a verified local file to retain its sharing protection.\n", stderr);
        return false;
    }

    HANDLE busy = CreateFileW(folder, DELETE, share, NULL, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, NULL);
    if (busy == INVALID_HANDLE_VALUE) return false;
    pinned = pin_icon_path(file, false, &pin);
    CloseHandle(busy);
    if (pinned) {
        unpin_icon_path(&pin);
        fputs("Expected a type fallback for a file in a busy directory.\n", stderr);
        return false;
    }
    return true;
}

int main(void) {
    WCHAR short_temp[MAX_PATH], temp[MAX_PATH], folder[MAX_PATH], file[MAX_PATH];
    DWORD length = GetTempPathW(ARRAYSIZE(short_temp), short_temp);
    if (!length || length >= ARRAYSIZE(short_temp)) return 1;
    // Some hosted accounts publish an 8.3 alias in TEMP. Exercise a normal
    // path since the production policy deliberately declines short-name aliases.
    length = GetLongPathNameW(short_temp, temp, ARRAYSIZE(temp));
    if (!length || length >= ARRAYSIZE(temp)) return 1;
    const WCHAR *separator = temp[length - 1] == L'\\' ? L"" : L"\\";
    int used = swprintf(folder, ARRAYSIZE(folder), L"%ls%lsDrill icon fixture %lu-%llu",
                        temp, separator, GetCurrentProcessId(), (unsigned long long)GetTickCount64());
    if (used <= 0 || (size_t)used >= ARRAYSIZE(folder)) return 1;
    used = swprintf(file, ARRAYSIZE(file), L"%ls\\example.txt", folder);
    if (used <= 0 || (size_t)used >= ARRAYSIZE(file) || !CreateDirectoryW(folder, NULL)) return 1;
    bool ok = test_pins(folder, file);
    if (!DeleteFileW(file) || !RemoveDirectoryW(folder)) ok = false;
    if (ok) puts("Native icon file, directory and fallback sharing checks passed.");
    return ok ? 0 : 1;
}
