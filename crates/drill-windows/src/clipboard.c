#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>

typedef void (*accept_text)(void *context, const WCHAR *text, size_t length);

static bool open_clipboard(HWND owner) {
    for (unsigned attempt = 0; attempt < 6; ++attempt) {
        if (OpenClipboard(owner)) {
            return true;
        }
        if (attempt < 5) {
            Sleep(5);
        }
    }
    return false;
}

void drill_windows_clipboard_read_text(void *context, accept_text accept) {
    if (!open_clipboard(NULL)) {
        return;
    }

    HGLOBAL memory = GetClipboardData(CF_UNICODETEXT);
    if (memory != NULL) {
        size_t size = GlobalSize(memory);
        const WCHAR *text = GlobalLock(memory);
        if (text != NULL) {
            if (size >= sizeof(*text) && size <= PTRDIFF_MAX) {
                size_t capacity = size / sizeof(*text);
                size_t length = 0;
                while (length < capacity && text[length] != 0) {
                    ++length;
                }
                accept(context, text, length);
            }
            GlobalUnlock(memory);
        }
    }
    CloseClipboard();
}

static HGLOBAL clipboard_bytes(const void *bytes, size_t size) {
    HGLOBAL memory = GlobalAlloc(GHND, size);
    if (memory == NULL) {
        return NULL;
    }
    void *data = GlobalLock(memory);
    if (data == NULL) {
        GlobalFree(memory);
        return NULL;
    }
    memcpy(data, bytes, size);
    GlobalUnlock(memory);
    return memory;
}

static bool publish(UINT format, HGLOBAL *memory) {
    if (*memory == NULL || SetClipboardData(format, *memory) == NULL) {
        return false;
    }
    // SetClipboardData transfers the unlocked allocation to Windows.
    *memory = NULL;
    return true;
}

bool drill_windows_clipboard_write_text(HWND owner, const WCHAR *text, size_t length) {
    HGLOBAL memory = clipboard_bytes(text, length * sizeof(*text));
    if (memory == NULL) {
        return false;
    }

    bool written = false;
    if (IsWindow(owner) && open_clipboard(owner)) {
        written = EmptyClipboard() && publish(CF_UNICODETEXT, &memory);
        CloseClipboard();
    }
    if (memory != NULL) {
        GlobalFree(memory);
    }
    return written;
}

static HGLOBAL clipboard_dib(LONG width, LONG height, const uint8_t *rgba, size_t size) {
    if (width <= 0 || height <= 0 || (uint64_t)width * (uint64_t)height * 4 != size ||
        size > UINT32_MAX || size > SIZE_MAX - sizeof(BITMAPV5HEADER)) {
        return NULL;
    }

    BITMAPV5HEADER header = {0};
    header.bV5Size = sizeof(header);
    header.bV5Width = width;
    header.bV5Height = height;
    header.bV5Planes = 1;
    header.bV5BitCount = 32;
    header.bV5Compression = BI_BITFIELDS;
    header.bV5SizeImage = (DWORD)size;
    header.bV5RedMask = 0x00ff0000;
    header.bV5GreenMask = 0x0000ff00;
    header.bV5BlueMask = 0x000000ff;
    header.bV5AlphaMask = 0xff000000;
    header.bV5CSType = 0x73524742u; // LCS_sRGB is a multicharacter literal in the SDK.
    header.bV5Intent = LCS_GM_IMAGES;

    HGLOBAL memory = GlobalAlloc(GHND, sizeof(header) + size);
    if (memory == NULL) {
        return NULL;
    }
    uint8_t *data = GlobalLock(memory);
    if (data == NULL) {
        GlobalFree(memory);
        return NULL;
    }
    memcpy(data, &header, sizeof(header));
    uint8_t *dst = data + sizeof(header);
    size_t stride = (size_t)width * 4;
    // Publish a bottom-up BGRA bitmap for consumers that reject top-down DIBs.
    for (LONG row = height; row > 0; --row) {
        const uint8_t *src = rgba + (size_t)(row - 1) * stride;
        for (LONG column = 0; column < width; ++column, src += 4, dst += 4) {
            dst[0] = src[2];
            dst[1] = src[1];
            dst[2] = src[0];
            dst[3] = src[3];
        }
    }
    GlobalUnlock(memory);
    return memory;
}

bool drill_windows_clipboard_write_image(HWND owner, LONG width, LONG height,
                                         const uint8_t *rgba, size_t rgba_size,
                                         const uint8_t *png, size_t png_size) {
    UINT png_format = png_size != 0 ? RegisterClipboardFormatW(L"PNG") : 0;
    HGLOBAL png_memory = png_format != 0 ? clipboard_bytes(png, png_size) : NULL;
    HGLOBAL dib_memory = clipboard_dib(width, height, rgba, rgba_size);

    bool written = false;
    if ((png_memory != NULL || dib_memory != NULL) && IsWindow(owner) && open_clipboard(owner)) {
        if (EmptyClipboard()) {
            // Consumers that take the first supported format should prefer PNG.
            bool png_written = publish(png_format, &png_memory);
            bool dib_written = publish(CF_DIBV5, &dib_memory);
            written = png_written || dib_written;
        }
        CloseClipboard();
    }
    if (png_memory != NULL) {
        GlobalFree(png_memory);
    }
    if (dib_memory != NULL) {
        GlobalFree(dib_memory);
    }
    return written;
}
