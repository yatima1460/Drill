#ifndef DRILL_WINDOW_ICON_PATH_H
#define DRILL_WINDOW_ICON_PATH_H

#include <windows.h>
#include <stdbool.h>
#include <wchar.h>
#include <string.h>

enum { TYPE_LENGTH = 32, ICON_VOLUME_LENGTH = 64 };
typedef WCHAR DrillTypeName[TYPE_LENGTH];

static bool same_icon_type(const WCHAR *left, const WCHAR *right) {
    return CompareStringOrdinal(left, -1, right, -1, TRUE) == CSTR_EQUAL;
}

// Synthetic type lookups receive only the extension, never a path or ADS.
static void icon_type_name(const WCHAR *path, DrillTypeName output) {
    const WCHAR *dot = wcsrchr(path, L'.');
    output[0] = 0;
    if (!dot || dot[1] == 0) return;
    size_t length = 0;
    while (dot[length]) {
        if (length + 1 >= TYPE_LENGTH || dot[length] < L' ' ||
            wcschr(L"\\/:*?\"<>|", dot[length])) return;
        ++length;
    }
    memcpy(output, dot, (length + 1) * sizeof(WCHAR));
}

// These formats can refer to another Shell object or supply icon resources
// themselves. Keep even a cache lookup from binding those paths in the Shell.
static bool icon_source_extension(const WCHAR *extension) {
    static const WCHAR *const types[] = {
        L".exe", L".appimage", L".dll", L".com", L".cpl", L".ocx", L".scr", L".sys",
        L".lnk", L".url", L".pif", L".scf", L".theme", L".themepack", L".library-ms",
        L".search-ms", L".searchconnector-ms", L".appref-ms", L".application", L".gadget",
        L".ico", L".icl", L".cur", L".ani", L".fon", L".fot", L".ttf", L".otf", L".ttc"
    };
    for (size_t i = 0; i < ARRAYSIZE(types); ++i)
        if (same_icon_type(extension, types[i])) return true;
    return false;
}

// DOS device aliases apply even if the name has an extension.
static bool icon_device_component(const WCHAR *part) {
    size_t n = wcscspn(part, L".");
    while (n && part[n - 1] == L' ') --n;
    if (n == 3) {
        return CompareStringOrdinal(part, 3, L"CON", 3, TRUE) == CSTR_EQUAL ||
               CompareStringOrdinal(part, 3, L"NUL", 3, TRUE) == CSTR_EQUAL ||
               CompareStringOrdinal(part, 3, L"AUX", 3, TRUE) == CSTR_EQUAL ||
               CompareStringOrdinal(part, 3, L"PRN", 3, TRUE) == CSTR_EQUAL;
    }
    if (n == 4 && wcschr(L"0123456789\x00b9\x00b2\x00b3", part[3])) {
        return CompareStringOrdinal(part, 3, L"COM", 3, TRUE) == CSTR_EQUAL ||
               CompareStringOrdinal(part, 3, L"LPT", 3, TRUE) == CSTR_EQUAL;
    }
    return (n == 6 && CompareStringOrdinal(part, 6, L"CONIN$", 6, TRUE) == CSTR_EQUAL) ||
           (n == 7 && CompareStringOrdinal(part, 7, L"CONOUT$", 7, TRUE) == CSTR_EQUAL);
}

typedef struct {
    WCHAR path[MAX_PATH + ICON_VOLUME_LENGTH];
    HANDLE handles[MAX_PATH / 2 + 2];
    size_t count;
} DrillPinnedIcon;

// A successful pin owns the root and every component until the Shell finishes
// its cache-only lookup. On failure pin_icon_path has already released them.
static void unpin_icon_path(DrillPinnedIcon *pin) {
    while (pin->count) CloseHandle(pin->handles[--pin->count]);
}

static bool pin_icon_component(DrillPinnedIcon *pin, bool directory) {
    // Metadata-only opens do not participate in Windows share reservations.
    // FILE_READ_DATA is FILE_LIST_DIRECTORY when the component is a folder.
    HANDLE handle = CreateFileW(pin->path, FILE_READ_DATA | FILE_READ_ATTRIBUTES, FILE_SHARE_READ,
        NULL, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT |
        FILE_FLAG_OPEN_NO_RECALL, NULL);
    if (handle == INVALID_HANDLE_VALUE) return false;
    pin->handles[pin->count++] = handle;
    BY_HANDLE_FILE_INFORMATION info;
    if (GetFileType(handle) != FILE_TYPE_DISK || !GetFileInformationByHandle(handle, &info) ||
        (info.dwFileAttributes & (FILE_ATTRIBUTE_REPARSE_POINT | FILE_ATTRIBUTE_OFFLINE |
         FILE_ATTRIBUTE_RECALL_ON_OPEN | FILE_ATTRIBUTE_RECALL_ON_DATA_ACCESS)) ||
        ((info.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0) != directory) return false;

    // Reject aliases, including short names that disguise excluded file types.
    WCHAR actual[ARRAYSIZE(pin->path)];
    DWORD length = GetFinalPathNameByHandleW(handle, actual, ARRAYSIZE(actual),
                                             FILE_NAME_NORMALIZED | VOLUME_NAME_GUID);
    return length && length < ARRAYSIZE(actual) && same_icon_type(actual, pin->path);
}

// Use the drive letter only to identify a fixed, directly mounted volume.
// SUBST maps to a path, whereas a mounted drive and its volume GUID map to the
// same NT device. All subsequent file opens and the Shell use the volume GUID.
static bool icon_volume_root(WCHAR letter, WCHAR root[ICON_VOLUME_LENGTH]) {
    WCHAR drive[] = {letter, L':', L'\\', 0};
    if (GetDriveTypeW(drive) != DRIVE_FIXED ||
        !GetVolumeNameForVolumeMountPointW(drive, root, ICON_VOLUME_LENGTH) ||
        GetDriveTypeW(root) != DRIVE_FIXED) return false;
    const WCHAR prefix[] = L"\\\\?\\Volume{";
    size_t length = wcslen(root);
    if (length != (ARRAYSIZE(prefix) - 1) + 36 + 2 ||
        wcsncmp(root, prefix, ARRAYSIZE(prefix) - 1) ||
        root[length - 2] != L'}' || root[length - 1] != L'\\') return false;
    WCHAR drive_target[MAX_PATH], volume_target[MAX_PATH];
    drive[2] = 0;
    root[length - 1] = 0;
    bool mounted = QueryDosDeviceW(drive, drive_target, ARRAYSIZE(drive_target)) &&
        QueryDosDeviceW(root + 4, volume_target, ARRAYSIZE(volume_target)) &&
        same_icon_type(drive_target, volume_target);
    root[length - 1] = L'\\';
    return mounted;
}

static bool pin_icon_path(const WCHAR *path, bool directory, DrillPinnedIcon *pin) {
    pin->count = 0;
    bool letter = (path[0] >= L'A' && path[0] <= L'Z') || (path[0] >= L'a' && path[0] <= L'z');
    if (!letter || path[1] != L':' || path[2] != L'\\' || !path[3] || wcslen(path) >= MAX_PATH ||
        wcspbrk(path + 3, L"/:*\"<>?|") || wcsstr(path, L".{") ||
        !icon_volume_root(path[0], pin->path)) return false;

    if (pin_icon_component(pin, true)) {
        WCHAR *part = pin->path + wcslen(pin->path);
        memcpy(part, path + 3, (wcslen(path + 3) + 1) * sizeof(WCHAR));
        while (*part) {
            WCHAR *end = wcschr(part, L'\\');
            if (!end) end = part + wcslen(part);
            if (end == part || end[-1] == L' ' || end[-1] == L'.') break;
            WCHAR separator = *end;
            *end = 0;
            DrillTypeName extension;
            icon_type_name(part, extension);
            bool safe = !icon_device_component(part) && !icon_source_extension(extension) &&
                        pin_icon_component(pin, separator || directory);
            *end = separator;
            if (!safe) break;
            if (!separator) return true;
            part = end + 1;
        }
    }
    unpin_icon_path(pin);
    return false;
}

#endif
