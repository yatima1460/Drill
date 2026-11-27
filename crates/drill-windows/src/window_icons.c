#include <windows.h>
#include <commctrl.h>
#include <shellapi.h>
#include <shobjidl.h>
#include <objbase.h>
#include <wchar.h>
#include <stdlib.h>
#include <string.h>
#include "../../drill-desktop/include/DrillDesktop.h"
#include "window_icon_path.h"

enum { ICON_SIDE = 32, ICON_SLOTS = 192, TYPE_JOBS = 64 };
static const WCHAR type_worker_property[] = L"software.drill.TypeIcons";

typedef struct {
    enum { TYPE_FREE, TYPE_QUEUED, TYPE_LOADING, TYPE_DONE } state;
    uint64_t id, generation;
    DrillTypeName extension;
    WCHAR path[MAX_PATH];
    bool directory;
    HICON icon;
} DrillTypeJob;

typedef struct {
    SRWLOCK lock;
    CONDITION_VARIABLE changed;
    HWND table;
    bool closing;
    DrillTypeJob jobs[TYPE_JOBS];
} DrillTypeWorker;

typedef struct {
    uint64_t id;  // Embedded icons use the model's stable row ID. Types share an entry.
    DrillTypeName extension;
    uint64_t used;
} DrillIconSlot;

typedef struct DrillWinIcons {
    HWND owner, table;
    DrillModel *model;
    DrillTypeWorker *worker;
    HIMAGELIST images;
    int file, folder, first_slot, count, size;
    uint64_t clock, generation;
    uint64_t misses[512];
    DrillIconSlot slots[ICON_SLOTS];
} DrillWinIcons;

// The Shell can return a transparent placeholder, particularly under Wine.
static bool shell_bitmap_visible(HBITMAP color, LONG width, LONG height) {
    RGBQUAD pixels[ICON_SIDE * ICON_SIDE];
    BITMAPINFO layout = {0};
    layout.bmiHeader.biSize = sizeof(layout.bmiHeader);
    layout.bmiHeader.biWidth = width;
    layout.bmiHeader.biHeight = -height;
    layout.bmiHeader.biPlanes = 1;
    layout.bmiHeader.biBitCount = 32;
    layout.bmiHeader.biCompression = BI_RGB;
    HDC dc = CreateCompatibleDC(NULL);
    if (!dc) return false;
    int rows = GetDIBits(dc, color, 0, (UINT)height, pixels, &layout, DIB_RGB_COLORS);
    DeleteDC(dc);
    if (rows != height) return false;
    for (LONG i = 0; i < width * height; ++i)
        if (pixels[i].rgbReserved) return true;
    return false;
}

static HICON cached_shell_icon(const WCHAR *path) {
    IShellItemImageFactory *factory = NULL;
    if (FAILED(SHCreateItemFromParsingName(path, NULL, &IID_IShellItemImageFactory,
                                            (void **)&factory))) return NULL;
    HBITMAP color = NULL;
    SIZE size = {ICON_SIDE, ICON_SIDE};
    // Windows can return Explorer's cached per-instance icon, including a
    // customized folder icon. Never ask it to extract from a file or icon URL.
    HRESULT hr = factory->lpVtbl->GetImage(factory, size, SIIGBF_ICONONLY | SIIGBF_INCACHEONLY, &color);
    factory->lpVtbl->Release(factory);
    BITMAP bitmap;
    HICON icon = NULL;
    if (SUCCEEDED(hr) && color && GetObjectW(color, sizeof(bitmap), &bitmap) == sizeof(bitmap) &&
        bitmap.bmWidth > 0 && bitmap.bmWidth <= ICON_SIDE &&
        bitmap.bmHeight > 0 && bitmap.bmHeight <= ICON_SIDE &&
        shell_bitmap_visible(color, bitmap.bmWidth, bitmap.bmHeight)) {
        BYTE bits[ICON_SIDE * ICON_SIDE / 8] = {0};
        HBITMAP mask = CreateBitmap(bitmap.bmWidth, bitmap.bmHeight, 1, 1, bits);
        if (mask) {
            ICONINFO info = {0};
            info.fIcon = TRUE;
            info.hbmColor = color;
            info.hbmMask = mask;
            icon = CreateIconIndirect(&info);
            DeleteObject(mask);
        }
    }
    if (color) DeleteObject(color);
    return icon;
}

static HICON local_item_icon(const WCHAR *path, bool directory) {
    DrillPinnedIcon pin;
    if (!pin_icon_path(path, directory, &pin)) return NULL;
    HICON icon = cached_shell_icon(pin.path);
    unpin_icon_path(&pin);
    return icon;
}

static DWORD WINAPI type_icon_thread(void *data) {
    DrillTypeWorker *worker = data;
    HRESULT com = CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);
    AcquireSRWLockExclusive(&worker->lock);
    while (!worker->closing) {
        DrillTypeJob *job = NULL;
        for (unsigned i = 0; i < TYPE_JOBS; ++i) {
            if (worker->jobs[i].state == TYPE_QUEUED) {
                job = &worker->jobs[i];
                break;
            }
        }
        if (!job) {
            SleepConditionVariableSRW(&worker->changed, &worker->lock, INFINITE, 0);
            continue;
        }
        // A loading slot stays reserved until this worker publishes the result.
        job->state = TYPE_LOADING;
        ReleaseSRWLockExclusive(&worker->lock);
        HICON icon = NULL;
        if (SUCCEEDED(com) && job->id) {
            icon = local_item_icon(job->path, job->directory);
        } else if (SUCCEEDED(com)) {
            SHFILEINFOW info = {0};
            SHGetFileInfoW(job->extension, FILE_ATTRIBUTE_NORMAL, &info, sizeof(info),
                           SHGFI_USEFILEATTRIBUTES | SHGFI_ICON | SHGFI_LARGEICON);
            icon = info.hIcon;
        }
        AcquireSRWLockExclusive(&worker->lock);
        job->icon = icon;
        job->state = TYPE_DONE;
        if (!worker->closing && GetPropW(worker->table, type_worker_property) == worker)
            InvalidateRect(worker->table, NULL, FALSE);
    }
    ReleaseSRWLockExclusive(&worker->lock);
    for (unsigned i = 0; i < TYPE_JOBS; ++i)
        if (worker->jobs[i].icon) DestroyIcon(worker->jobs[i].icon);
    if (SUCCEEDED(com)) CoUninitialize();
    free(worker);
    return 0;
}

static DrillTypeWorker *start_type_worker(HWND table) {
    DrillTypeWorker *worker = calloc(1, sizeof(*worker));
    if (!worker) return NULL;
    InitializeSRWLock(&worker->lock);
    InitializeConditionVariable(&worker->changed);
    worker->table = table;
    if (SetPropW(table, type_worker_property, worker)) {
        HANDLE thread = CreateThread(NULL, 0, type_icon_thread, worker, 0, NULL);
        if (thread) {
            CloseHandle(thread);
            return worker;
        }
        RemovePropW(table, type_worker_property);
    }
    free(worker);
    return NULL;
}

// Take a completed icon or enqueue its type. Failed lookups stay cached until
// another type needs the slot. Excess requests retry on the next invalidation.
static HICON request_shell_icon(DrillWinIcons *icons, uint64_t id, const WCHAR *extension,
                                const WCHAR *path, size_t length, bool directory) {
    DrillTypeWorker *worker = icons->worker;
    if (!worker) return NULL;
    HICON result = NULL;
    DrillTypeJob *available = NULL;
    AcquireSRWLockExclusive(&worker->lock);
    for (unsigned i = 0; i < TYPE_JOBS; ++i) {
        DrillTypeJob *job = &worker->jobs[i];
        if (job->state != TYPE_FREE && job->id == id &&
            (id ? job->generation == icons->generation : same_icon_type(extension, job->extension))) {
            if (job->state == TYPE_DONE && (id || job->icon)) {
                result = job->icon;
                job->icon = NULL;
                job->state = TYPE_FREE;
                if (id && !result) icons->misses[id % ARRAYSIZE(icons->misses)] = id;
            }
            ReleaseSRWLockExclusive(&worker->lock);
            return result;
        }
        if (job->state == TYPE_FREE || (!available && job->state == TYPE_DONE))
            available = job;
    }
    if (available) {
        if (available->icon) DestroyIcon(available->icon);
        available->icon = NULL;
        available->id = id;
        available->generation = icons->generation;
        available->directory = directory;
        if (id) memcpy(available->path, path, (length + 1) * sizeof(WCHAR));
        else memcpy(available->extension, extension, (wcslen(extension) + 1) * sizeof(WCHAR));
        available->state = TYPE_QUEUED;
        WakeConditionVariable(&worker->changed);
    }
    ReleaseSRWLockExclusive(&worker->lock);
    return NULL;
}

static HICON rgba_result_icon(const uint8_t *rgba) {
    BITMAPINFO info = {0};
    info.bmiHeader.biSize = sizeof(info.bmiHeader);
    info.bmiHeader.biWidth = ICON_SIDE;
    info.bmiHeader.biHeight = -ICON_SIDE;
    info.bmiHeader.biPlanes = 1;
    info.bmiHeader.biBitCount = 32;
    info.bmiHeader.biCompression = BI_RGB;
    uint8_t *pixels = NULL;
    HBITMAP color = CreateDIBSection(NULL, &info, DIB_RGB_COLORS, (void **)&pixels, NULL, 0);
    if (!color) return NULL;
    BYTE mask_bits[ICON_SIDE * ICON_SIDE / 8] = {0};
    // CreateIconIndirect expects premultiplied BGRA pixels.
    for (int i = 0; i < ICON_SIDE * ICON_SIDE; ++i, pixels += 4, rgba += 4) {
        unsigned alpha = rgba[3];
        pixels[0] = (uint8_t)((rgba[2] * alpha + 127) / 255);
        pixels[1] = (uint8_t)((rgba[1] * alpha + 127) / 255);
        pixels[2] = (uint8_t)((rgba[0] * alpha + 127) / 255);
        pixels[3] = (uint8_t)alpha;
        if (!alpha) mask_bits[i / 8] |= (BYTE)(0x80 >> (i % 8));
    }
    HBITMAP mask = CreateBitmap(ICON_SIDE, ICON_SIDE, 1, 1, mask_bits);
    HICON icon = NULL;
    if (mask) {
        ICONINFO image = {0};
        image.fIcon = TRUE;
        image.hbmMask = mask;
        image.hbmColor = color;
        icon = CreateIconIndirect(&image);
        DeleteObject(mask);
    }
    DeleteObject(color);
    return icon;
}

static int stock_list_icon(HIMAGELIST images, SHSTOCKICONID id) {
    SHSTOCKICONINFO info = {0};
    info.cbSize = sizeof(info);
    if (SUCCEEDED(SHGetStockIconInfo(id, SHGSI_ICON | SHGSI_LARGEICON, &info)) && info.hIcon) {
        int index = ImageList_AddIcon(images, info.hIcon);
        DestroyIcon(info.hIcon);
        if (index >= 0) return index;
    }
    return ImageList_AddIcon(images, LoadIconW(NULL, MAKEINTRESOURCEW(32512))); // IDI_APPLICATION
}

void drill_win_icons_reset(DrillWinIcons *icons) {
    if (!icons) return;
    // Resolve at runtime for older SDKs and Windows versions.
    union { FARPROC proc; UINT (WINAPI *call)(HWND); } dpi = {
        GetProcAddress(GetModuleHandleW(L"user32.dll"), "GetDpiForWindow")
    };
    UINT scale = dpi.call ? dpi.call(icons->owner) : 96;
    int size = MulDiv(ICON_SIDE, (int)(scale ? scale : 96), 96);
    if (size > 192) size = 192;
    icons->count = 0;
    icons->clock = 0;
    ++icons->generation;
    memset(icons->misses, 0, sizeof(icons->misses));
    if (icons->worker) {
        AcquireSRWLockExclusive(&icons->worker->lock);
        for (unsigned i = 0; i < TYPE_JOBS; ++i) {
            DrillTypeJob *job = &icons->worker->jobs[i];
            if (job->id && job->state != TYPE_LOADING) {
                if (job->icon) DestroyIcon(job->icon);
                job->state = TYPE_FREE;
                job->icon = NULL;
            }
        }
        ReleaseSRWLockExclusive(&icons->worker->lock);
    }
    if (icons->images && icons->size == size) return;
    icons->size = size;
    HIMAGELIST images = ImageList_Create(size, size, ILC_COLOR32 | ILC_MASK, 2, 8);
    HIMAGELIST previous = icons->images;
    icons->images = images;
    icons->file = images ? stock_list_icon(images, SIID_DOCNOASSOC) : -1;
    icons->folder = images ? stock_list_icon(images, SIID_FOLDER) : -1;
    icons->first_slot = images ? ImageList_GetImageCount(images) : 0;
    ListView_SetImageList(icons->table, images, LVSIL_SMALL);
    if (previous) ImageList_Destroy(previous);
}

DrillWinIcons *drill_win_icons_create(HWND owner, HWND table, DrillModel *model) {
    DrillWinIcons *icons = calloc(1, sizeof(*icons));
    if (icons) {
        icons->owner = owner;
        icons->table = table;
        icons->model = model;
        icons->worker = start_type_worker(table);
        drill_win_icons_reset(icons);
    }
    return icons;
}

void drill_win_icons_destroy(DrillWinIcons *icons) {
    if (!icons) return;
    DrillTypeWorker *worker = icons->worker;
    if (worker) {
        AcquireSRWLockExclusive(&worker->lock);
        if (GetPropW(icons->table, type_worker_property) == worker)
            RemovePropW(icons->table, type_worker_property);
        worker->closing = true;
        WakeConditionVariable(&worker->changed);
        ReleaseSRWLockExclusive(&worker->lock);
        // The worker releases itself even if Windows is still resolving a type.
    }
    if (icons->images) {
        if (IsWindow(icons->table) && ListView_GetImageList(icons->table, LVSIL_SMALL) == icons->images)
            ListView_SetImageList(icons->table, NULL, LVSIL_SMALL);
        ImageList_Destroy(icons->images);
    }
    free(icons);
}

// The owner-data table requests each index while painting. Reuse the least
// recently drawn slot so scrolling an arbitrarily large search stays bounded.
static int find_list_icon(DrillWinIcons *icons, uint64_t id, const WCHAR *extension) {
    for (int i = 0; i < icons->count; ++i) {
        DrillIconSlot *slot = &icons->slots[i];
        if (slot->id == id && (id || same_icon_type(slot->extension, extension))) {
            slot->used = ++icons->clock;
            return icons->first_slot + i;
        }
    }
    return -1;
}

static int store_list_icon(DrillWinIcons *icons, uint64_t id, const WCHAR *extension, HICON image) {
    int slot = icons->count;
    if (slot == ICON_SLOTS) {
        slot = 0;
        for (int i = 1; i < icons->count; ++i)
            if (icons->slots[i].used < icons->slots[slot].used) slot = i;
    }
    int position = icons->first_slot + slot;
    int index = ImageList_ReplaceIcon(icons->images,
        position < ImageList_GetImageCount(icons->images) ? position : -1, image);
    DestroyIcon(image);
    if (index < 0) return icons->file;
    if (slot == icons->count) ++icons->count;
    icons->slots[slot].id = id;
    icons->slots[slot].used = ++icons->clock;
    if (!id) memcpy(icons->slots[slot].extension, extension, (wcslen(extension) + 1) * sizeof(WCHAR));
    return index;
}

int drill_win_icons_get(DrillWinIcons *icons, uint64_t id, bool exe, bool appimage) {
    if (!icons || !icons->images || !id) return -1;
    DrillRow row;
    if (!drill_row(icons->model, id, &row)) return -1;
    const WCHAR *path = (const WCHAR *)row.path;
    DrillTypeName extension;
    icon_type_name(path, extension);
    int cached = find_list_icon(icons, id, NULL);
    if (cached >= 0) return cached;
    // Copy the borrowed native path before any model mutation. Long or verbatim
    // paths still open losslessly and use a file-type icon for display.
    if (icons->misses[id % ARRAYSIZE(icons->misses)] != id && !icon_source_extension(extension)) {
        size_t length = 0;
        while (length < MAX_PATH && path[length]) ++length;
        if (length < MAX_PATH) {
            HICON image = request_shell_icon(icons, id, NULL, path, length, row.directory);
            if (image) return store_list_icon(icons, id, NULL, image);
        }
    }
    if (row.directory) return icons->folder;
    if (!*extension) return icons->file;
    if ((exe && same_icon_type(extension, L".exe")) ||
        (appimage && same_icon_type(extension, L".appimage"))) {
        uint8_t rgba[ICON_SIDE * ICON_SIDE * 4];
        if (drill_embedded_icon(icons->model, id, exe, appimage, rgba) == 1) {
            HICON image = rgba_result_icon(rgba);
            if (image) return store_list_icon(icons, id, NULL, image);
        }
    }
    int index = find_list_icon(icons, 0, extension);
    if (index >= 0) return index;
    HICON image = request_shell_icon(icons, 0, extension, NULL, 0, false);
    return image ? store_list_icon(icons, 0, extension, image) : icons->file;
}
