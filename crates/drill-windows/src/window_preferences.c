// Native settings use one DWORD per preference so simultaneous instances can
// change different settings independently. Carry over the previous UI's values.
#include <windows.h>
#include <shlobj.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>

enum { WIN_APPEARANCE, WIN_EXE_ICONS, WIN_APPIMAGE_ICONS, WIN_PREF_COUNT };
static const WCHAR win_pref_key[] = L"Software\\Drill\\Interface";
static const WCHAR *const win_pref_names[] = {L"Appearance", L"ShowExeIcons", L"ShowAppImageIcons"};

static WCHAR *win_known_file(REFKNOWNFOLDERID folder, const WCHAR *suffix) {
    WCHAR *base = NULL;
    if (FAILED(SHGetKnownFolderPath(folder, KF_FLAG_DONT_VERIFY, NULL, &base))) {
        CoTaskMemFree(base);
        return NULL;
    }
    size_t base_len = wcslen(base), suffix_len = wcslen(suffix) + 1;
    WCHAR *path = malloc((base_len + suffix_len) * sizeof(*path));
    if (path) {
        memcpy(path, base, base_len * sizeof(*path));
        memcpy(path + base_len, suffix, suffix_len * sizeof(*path));
    }
    CoTaskMemFree(base);
    return path;
}

static bool win_read_dword(const WCHAR *key, const WCHAR *name, DWORD *value) {
    DWORD bytes = sizeof(*value);
    return RegGetValueW(HKEY_CURRENT_USER, key, name, RRF_RT_REG_DWORD, NULL, value, &bytes) == ERROR_SUCCESS;
}

static LSTATUS win_write_pref(unsigned key, DWORD value) {
    return RegSetKeyValueW(HKEY_CURRENT_USER, win_pref_key, win_pref_names[key],
                           REG_DWORD, &value, sizeof(value));
}

// The released eframe writer pretty-prints one quoted string pair per line.
// Match whole entries so a value embedded in window geometry cannot impersonate a key.
static void win_read_legacy_prefs(DWORD values[WIN_PREF_COUNT]) {
    WCHAR *path = win_known_file(&FOLDERID_RoamingAppData, L"\\Drill\\data\\app.ron");
    if (!path) return;
    HANDLE file = CreateFileW(path, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                              NULL, OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, NULL);
    free(path);
    if (file == INVALID_HANDLE_VALUE) return;
    BY_HANDLE_FILE_INFORMATION info;
    char *text = NULL;
    DWORD size = 0, count = 0;
    if (GetFileType(file) == FILE_TYPE_DISK && GetFileInformationByHandle(file, &info) &&
        !(info.dwFileAttributes & (FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT)) &&
        info.nFileSizeHigh == 0 && info.nFileSizeLow <= 64 * 1024) {
        size = info.nFileSizeLow;
        text = malloc(size + 1);
    }
    bool ok = text && ReadFile(file, text, size, &count, NULL) && count == size;
    CloseHandle(file);
    if (ok) {
        text[size] = 0;
        static const struct { const char *entry; unsigned key; DWORD value; } entries[] = {
            {"\"appearance\": \"System\",", WIN_APPEARANCE, 0},
            {"\"appearance\": \"Light\",", WIN_APPEARANCE, 1},
            {"\"appearance\": \"Dark\",", WIN_APPEARANCE, 2},
            {"\"embedded_exe_icons\": \"false\",", WIN_EXE_ICONS, 0},
            {"\"embedded_exe_icons\": \"true\",", WIN_EXE_ICONS, 1},
            {"\"embedded_appimage_icons\": \"false\",", WIN_APPIMAGE_ICONS, 0},
            {"\"embedded_appimage_icons\": \"true\",", WIN_APPIMAGE_ICONS, 1},
        };
        char *line = text;
        while (*line) {
            char *end = line + strcspn(line, "\r\n");
            char *next = end + strspn(end, "\r\n");
            *end = 0;
            line += strspn(line, " \t");
            for (size_t i = 0; i < ARRAYSIZE(entries); ++i) {
                if (strcmp(line, entries[i].entry) == 0) values[entries[i].key] = entries[i].value;
            }
            line = next;
        }
    }
    free(text);
}

static void win_load_prefs(DWORD values[WIN_PREF_COUNT]) {
    DWORD legacy[WIN_PREF_COUNT] = {MAXDWORD, MAXDWORD, MAXDWORD};
    bool loaded_legacy = false;
    for (unsigned i = 0; i < WIN_PREF_COUNT; ++i) {
        DWORD value;
        if (win_read_dword(win_pref_key, win_pref_names[i], &value) && value <= (i == WIN_APPEARANCE ? 2u : 1u)) {
            values[i] = value;
            continue;
        }
        if (!loaded_legacy) {
            win_read_legacy_prefs(legacy);
            loaded_legacy = true;
        }
        if (legacy[i] != MAXDWORD) {
            values[i] = legacy[i];
            win_write_pref(i, values[i]);
        } else {
            values[i] = i != WIN_APPEARANCE;
        }
    }
}

static bool win_resolve_dark(DWORD preference) {
    HIGHCONTRASTW contrast = {0};
    contrast.cbSize = sizeof(contrast);
    if (SystemParametersInfoW(SPI_GETHIGHCONTRAST, sizeof(contrast), &contrast, 0) &&
        (contrast.dwFlags & HCF_HIGHCONTRASTON)) return false;
    if (preference != 0) return preference == 2;
    DWORD light;
    return win_read_dword(L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",
                          L"AppsUseLightTheme", &light) && light == 0;
}
