#import <AppKit/AppKit.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    uint8_t *bytes;
    size_t len;
} DrillPngData;

// Bundled app icons are at most 1024 pixels per side. Keep allocations bounded.
static size_t rgba_length(uint32_t width, uint32_t height) {
    if (width == 0 || height == 0 || width > 2048 || height > 2048) {
        return 0;
    }
    return (size_t)width * height * 4;
}

static uint32_t png_dimension(const uint8_t *bytes) {
    return ((uint32_t)bytes[0] << 24) | ((uint32_t)bytes[1] << 16) |
           ((uint32_t)bytes[2] << 8) | bytes[3];
}

DrillPngData drill_macos_png_decode(const uint8_t *png, size_t len,
                                   uint32_t *width_out, uint32_t *height_out) {
    // Check the signature and dimensions before handing the PNG to AppKit.
    static const uint8_t header[] = {
        0x89, 'P', 'N', 'G', '\r', '\n', 0x1a, '\n', 0, 0, 0, 13, 'I', 'H', 'D', 'R',
    };
    if (len < 33 || len > 16 * 1024 * 1024 || memcmp(png, header, sizeof(header)) != 0) {
        return (DrillPngData){0};
    }
    uint32_t width = png_dimension(png + 16);
    uint32_t height = png_dimension(png + 20);
    size_t rgba_len = rgba_length(width, height);
    if (rgba_len == 0) {
        return (DrillPngData){0};
    }

    @autoreleasepool {
        NSData *data = [NSData dataWithBytes:png length:len];
        if (!data) {
            return (DrillPngData){0};
        }
        NSBitmapImageRep *bitmap = [NSBitmapImageRep imageRepWithData:data];
        if (!bitmap || bitmap.pixelsWide != width || bitmap.pixelsHigh != height ||
            bitmap.isPlanar || !bitmap.hasAlpha || bitmap.bitsPerSample != 8 ||
            bitmap.bitmapFormat != NSBitmapFormatAlphaNonpremultiplied) {
            return (DrillPngData){0};
        }

        NSInteger channels = bitmap.samplesPerPixel;
        if ((channels != 4 && channels != 2) || bitmap.bitsPerPixel != channels * 8) {
            return (DrillPngData){0};
        }
        const uint8_t *pixels = bitmap.bitmapData;
        NSInteger stride = bitmap.bytesPerRow;
        NSInteger plane_len = bitmap.bytesPerPlane;
        if (!pixels || stride < (NSInteger)width * channels || plane_len / height < stride) {
            return (DrillPngData){0};
        }

        uint8_t *rgba = malloc(rgba_len);
        if (!rgba) {
            return (DrillPngData){0};
        }
        for (uint32_t y = 0; y < height; y++) {
            const uint8_t *source = pixels + y * (size_t)stride;
            uint8_t *row = rgba + (size_t)y * width * 4;
            if (channels == 4) {
                memcpy(row, source, (size_t)width * 4);
            } else {
                for (uint32_t x = 0; x < width; x++) {
                    row[x * 4] = source[x * 2];
                    row[x * 4 + 1] = source[x * 2];
                    row[x * 4 + 2] = source[x * 2];
                    row[x * 4 + 3] = source[x * 2 + 1];
                }
            }
        }
        *width_out = width;
        *height_out = height;
        return (DrillPngData){rgba, rgba_len};
    }
}

DrillPngData drill_macos_png_encode(const uint8_t *rgba, size_t len,
                                   uint32_t width, uint32_t height) {
    if (len == 0 || rgba_length(width, height) != len) {
        return (DrillPngData){0};
    }

    @autoreleasepool {
        NSInteger stride = (NSInteger)width * 4;
        NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
            pixelsWide:width pixelsHigh:height bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES
            isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace
            bitmapFormat:NSBitmapFormatAlphaNonpremultiplied bytesPerRow:stride bitsPerPixel:32];
        uint8_t *pixels = bitmap.bitmapData;
        if (!pixels || bitmap.bytesPerRow != stride || bitmap.bytesPerPlane < (NSInteger)len) {
            return (DrillPngData){0};
        }
        memcpy(pixels, rgba, len);

        NSData *data = [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
        if (data.length == 0) {
            return (DrillPngData){0};
        }
        uint8_t *png = malloc(data.length);
        if (!png) {
            return (DrillPngData){0};
        }
        memcpy(png, data.bytes, data.length);
        return (DrillPngData){png, data.length};
    }
}

void drill_macos_png_free(uint8_t *bytes) {
    free(bytes);
}
