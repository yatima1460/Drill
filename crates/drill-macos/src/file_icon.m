#import <AppKit/AppKit.h>
#include <stdint.h>
#include <string.h>

int drill_macos_file_icon(const uint8_t *path, size_t path_length, uint16_t size,
                         uint8_t *pixels, size_t capacity) {
    size_t length = (size_t)size * size * 4;
    if (size == 0 || size > 256 || length > capacity) {
        return 0;
    }

    @autoreleasepool {
        NSString *file = [[NSString alloc] initWithBytes:path
                                                   length:path_length
                                                 encoding:NSUTF8StringEncoding];
        if (!file) {
            return 0;
        }
        NSImage *image = [[NSWorkspace sharedWorkspace] iconForFile:file];
        NSBitmapImageRep *bitmap =
            [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                   pixelsWide:size
                                                   pixelsHigh:size
                                                bitsPerSample:8
                                              samplesPerPixel:4
                                                     hasAlpha:YES
                                                     isPlanar:NO
                                               colorSpaceName:NSDeviceRGBColorSpace
                                                  bytesPerRow:size * 4
                                                 bitsPerPixel:32];
        if (!image || !bitmap) {
            return 0;
        }
        NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
        if (!context) {
            return 0;
        }

        [NSGraphicsContext saveGraphicsState];
        [NSGraphicsContext setCurrentContext:context];
        [image drawInRect:NSMakeRect(0, 0, size, size)
                 fromRect:NSZeroRect
                operation:NSCompositingOperationCopy
                 fraction:1.0];
        [context flushGraphics];
        [NSGraphicsContext restoreGraphicsState];

        const uint8_t *data = [bitmap bitmapData];
        if (!data || [bitmap bytesPerPlane] != (NSInteger)length) {
            return 0;
        }
        memcpy(pixels, data, length);
        return 1;
    }
}
