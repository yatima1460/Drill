// Native settings use one DWORD per preference so simultaneous instances can
// change different settings independently. Carry over the previous UI's values.
#include <windows.h>
#include <shlobj.h>
#include <locale.h>
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

static char *win_legacy_settings_text(void) {
    WCHAR *path = win_known_file(&FOLDERID_RoamingAppData, L"\\Drill\\data\\app.ron");
    if (!path) return NULL;
    HANDLE file = CreateFileW(path, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                              NULL, OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, NULL);
    free(path);
    if (file == INVALID_HANDLE_VALUE) return NULL;
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
    if (!ok || memchr(text, 0, size)) {
        free(text);
        return NULL;
    }
    text[size] = 0;
    return text;
}

// The released eframe writer prints one quoted key and string value per line.
static char *win_next_legacy_entry(char **cursor) {
    if (!*cursor || !**cursor) return NULL;
    char *line = *cursor, *end = line + strcspn(line, "\r\n");
    *cursor = end + strspn(end, "\r\n");
    *end = 0;
    return line + strspn(line, " \t");
}

static void win_read_legacy_prefs(DWORD values[WIN_PREF_COUNT]) {
    static const struct { const char *entry; unsigned key; DWORD value; } entries[] = {
        {"\"appearance\": \"System\",", WIN_APPEARANCE, 0},
        {"\"appearance\": \"Light\",", WIN_APPEARANCE, 1},
        {"\"appearance\": \"Dark\",", WIN_APPEARANCE, 2},
        {"\"embedded_exe_icons\": \"false\",", WIN_EXE_ICONS, 0},
        {"\"embedded_exe_icons\": \"true\",", WIN_EXE_ICONS, 1},
        {"\"embedded_appimage_icons\": \"false\",", WIN_APPIMAGE_ICONS, 0},
        {"\"embedded_appimage_icons\": \"true\",", WIN_APPIMAGE_ICONS, 1},
    };
    char *text = win_legacy_settings_text(), *cursor = text;
    for (char *line; (line = win_next_legacy_entry(&cursor)) != NULL;) {
        for (size_t i = 0; i < ARRAYSIZE(entries); ++i) {
            if (strcmp(line, entries[i].entry) == 0) values[entries[i].key] = entries[i].value;
        }
    }
    free(text);
}

static bool win_legacy_consume(const char **line, const char *literal) {
    size_t length = strlen(literal);
    if (strncmp(*line, literal, length) != 0) return false;
    *line += length;
    return true;
}

static bool win_legacy_coordinate(const char **line, LONG *value) {
    // Parse eframe's decimal point independently of the calling thread's locale.
    _locale_t locale = _create_locale(LC_NUMERIC, "C");
    if (!locale) return false;
    char *end;
    double n = _strtod_l(*line, &end, locale);
    _free_locale(locale);
    // Only finite coordinates within a million pixels can reach the Win32 casts.
    if (end == *line || (size_t)(end - *line) != strspn(*line, "-+0123456789.eE") ||
        !(n >= -1000000 && n <= 1000000)) return false;
    *value = (LONG)(n < 0 ? n - 0.5 : n + 0.5);
    *line = end;
    return true;
}

static bool win_legacy_vector(const char **line, LONG *x, LONG *y) {
    return win_legacy_consume(line, "Some((x:") && win_legacy_coordinate(line, x) &&
           win_legacy_consume(line, ",y:") && win_legacy_coordinate(line, y) &&
           win_legacy_consume(line, "))");
}

// Read the exact WindowSettings record from the released eframe version.
// Origin is the physical screen position. Client size is measured in points.
static bool win_parse_legacy_placement(const char *line, POINT *origin, SIZE *client_dip, bool *maximized) {
    POINT inner, outer;
    SIZE size;
    if (!win_legacy_consume(&line, "\"window\": \"(inner_position_pixels:") ||
        !(win_legacy_consume(&line, "None") || win_legacy_vector(&line, &inner.x, &inner.y)) ||
        !win_legacy_consume(&line, ",outer_position_pixels:") || !win_legacy_vector(&line, &outer.x, &outer.y) ||
        !win_legacy_consume(&line, ",fullscreen:") ||
        !(win_legacy_consume(&line, "false") || win_legacy_consume(&line, "true")) ||
        !win_legacy_consume(&line, ",maximized:")) return false;
    bool max = win_legacy_consume(&line, "true");
    if ((!max && !win_legacy_consume(&line, "false")) ||
        !win_legacy_consume(&line, ",inner_size_points:") || !win_legacy_vector(&line, &size.cx, &size.cy) ||
        strcmp(line, ")\",") != 0 || size.cx <= 0 || size.cy <= 0 || size.cx > 65535 || size.cy > 65535) return false;
    *origin = outer;
    // eframe saved the maximized client size without the normal restore size.
    client_dip->cx = max ? 720 : size.cx;
    client_dip->cy = max ? 470 : size.cy;
    *maximized = max;
    return true;
}

static bool win_read_legacy_placement(POINT *origin, SIZE *client_dip, bool *maximized) {
    char *text = win_legacy_settings_text(), *cursor = text;
    bool found = false;
    for (char *line; (line = win_next_legacy_entry(&cursor)) != NULL;) {
        if (win_parse_legacy_placement(line, origin, client_dip, maximized)) {
            found = true;
            break;
        }
    }
    free(text);
    return found;
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
