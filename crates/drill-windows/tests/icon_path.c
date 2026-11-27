// A writable volume must always take the native type/folder fallback. Exercise
// a normal, closed file as well as a file whose own attributes are read-only.
#include "../src/window_icon_path.h"
#include <stdio.h>

static bool rejected_item(const WCHAR *path, bool directory) {
    DrillPinnedIcon pin = {0};
    if (!pin_icon_path(path, directory, &pin)) return pin.root == NULL;
    unpin_icon_path(&pin);
    fputs("A writable volume reached the per-item Shell lookup.\n", stderr);
    return false;
}

static bool test_writable_volume(const WCHAR *folder, const WCHAR *file) {
    HANDLE writer = CreateFileW(file, GENERIC_WRITE, 0, NULL, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, NULL);
    if (writer == INVALID_HANDLE_VALUE) return false;
    CloseHandle(writer);
    bool ok = rejected_item(folder, true) && rejected_item(file, false);
    if (!SetFileAttributesW(file, FILE_ATTRIBUTE_READONLY)) return false;
    ok = rejected_item(file, false) && ok;
    return SetFileAttributesW(file, FILE_ATTRIBUTE_NORMAL) && ok;
}

int main(void) {
    if (!icon_volume_eligible(DRIVE_FIXED, FILE_READ_ONLY_VOLUME | FILE_PERSISTENT_ACLS) ||
        icon_volume_eligible(DRIVE_FIXED, FILE_PERSISTENT_ACLS) ||
        icon_volume_eligible(DRIVE_REMOTE, FILE_READ_ONLY_VOLUME) ||
        icon_volume_eligible(DRIVE_UNKNOWN, FILE_READ_ONLY_VOLUME)) {
        fputs("Unexpected Windows volume eligibility.\n", stderr);
        return 1;
    }

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
    bool ok = test_writable_volume(folder, file);
    if (!DeleteFileW(file) || !RemoveDirectoryW(folder)) ok = false;
    if (ok) puts("Windows icon volume eligibility and file/folder fallback checks passed.");
    return ok ? 0 : 1;
}
