#define WIN32_LEAN_AND_MEAN
#define COBJMACROS
#include <windows.h>
#include <shobjidl.h>
#include <stdint.h>

static int read_icon_bitmap(HBITMAP bitmap, unsigned int size, uint8_t *pixels,
                            size_t capacity, uint32_t *width, uint32_t *height) {
    BITMAP metadata;
    if (GetObjectW(bitmap, sizeof(metadata), &metadata) != sizeof(metadata) ||
        metadata.bmWidth <= 0 || metadata.bmHeight <= 0 ||
        (unsigned int)metadata.bmWidth > size || (unsigned int)metadata.bmHeight > size) {
        return 0;
    }

    size_t length = (size_t)metadata.bmWidth * metadata.bmHeight * 4;
    if (length > capacity) {
        return 0;
    }

    BITMAPINFO info = {0};
    info.bmiHeader.biSize = sizeof(info.bmiHeader);
    info.bmiHeader.biWidth = metadata.bmWidth;
    info.bmiHeader.biHeight = -metadata.bmHeight; /* Top-down rows. */
    info.bmiHeader.biPlanes = 1;
    info.bmiHeader.biBitCount = 32;
    info.bmiHeader.biCompression = BI_RGB;

    HDC dc = CreateCompatibleDC(NULL);
    if (!dc) {
        return 0;
    }
    int rows = GetDIBits(dc, bitmap, 0, (UINT)metadata.bmHeight, pixels, &info, DIB_RGB_COLORS);
    DeleteDC(dc);
    if (rows != metadata.bmHeight) {
        return 0;
    }

    int visible = 0;
    for (size_t i = 0; i < length; i += 4) {
        uint8_t blue = pixels[i];
        pixels[i] = pixels[i + 2];
        pixels[i + 2] = blue;
        visible |= pixels[i + 3] != 0;
    }
    /* Wine's Shell can return an entirely transparent placeholder. */
    if (!visible) {
        return 0;
    }
    *width = (uint32_t)metadata.bmWidth;
    *height = (uint32_t)metadata.bmHeight;
    return 1;
}

int drill_read_shell_icon(const WCHAR *path, uint16_t size, uint8_t *pixels,
                          size_t capacity, uint32_t *width, uint32_t *height) {
    if (size == 0 || size > 256) {
        return 0;
    }
    if (FAILED(CoInitializeEx(NULL, COINIT_APARTMENTTHREADED))) {
        return 0;
    }

    int ok = 0;
    IShellItemImageFactory *factory = NULL;
    HRESULT result = SHCreateItemFromParsingName(path, NULL, &IID_IShellItemImageFactory,
                                                (void **)&factory);
    if (SUCCEEDED(result) && factory) {
        SIZE requested = {size, size};
        HBITMAP bitmap = NULL;
        result = IShellItemImageFactory_GetImage(factory, requested,
                                                SIIGBF_ICONONLY | SIIGBF_SCALEUP, &bitmap);
        if (bitmap) {
            if (SUCCEEDED(result)) {
                ok = read_icon_bitmap(bitmap, size, pixels, capacity, width, height);
            }
            DeleteObject(bitmap);
        }
        IShellItemImageFactory_Release(factory);
    }
    CoUninitialize();
    return ok;
}
