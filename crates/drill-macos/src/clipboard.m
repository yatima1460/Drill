#import <AppKit/AppKit.h>
#include <string.h>

#include "clipboard.h"

void *drill_macos_clipboard_open(void) {
    @autoreleasepool {
        return (__bridge_retained void *)NSPasteboard.generalPasteboard;
    }
}

void drill_macos_clipboard_close(void *handle) {
    (void)CFBridgingRelease(handle);
}

void drill_macos_clipboard_read_text(void *handle, void *context, DrillClipboardTextSink sink) {
    @autoreleasepool {
        NSPasteboard *pasteboard = (__bridge NSPasteboard *)handle;

        // Preserve the first text item when several objects were copied.
        for (NSPasteboardItem *item in pasteboard.pasteboardItems) {
            NSString *text = [item stringForType:NSPasteboardTypeString];
            if (text != nil) {
                NSData *encoded = [text dataUsingEncoding:NSUTF8StringEncoding];
                if (encoded != nil) {
                    sink(context, encoded.bytes, encoded.length);
                }
                return;
            }
        }
    }
}

bool drill_macos_clipboard_write_text(void *handle, const uint8_t *bytes, size_t length) {
    @autoreleasepool {
        NSPasteboard *pasteboard = (__bridge NSPasteboard *)handle;
        NSString *text = [[NSString alloc] initWithBytes:bytes length:length encoding:NSUTF8StringEncoding];
        if (text == nil) {
            return false;
        }
        [pasteboard clearContents];
        return [pasteboard setString:text forType:NSPasteboardTypeString];
    }
}

bool drill_macos_clipboard_write_rgba(void *handle, const uint8_t *rgba, size_t length, size_t width, size_t height) {
    if (width == 0 || height == 0 || width > NSIntegerMax / 4) {
        return false;
    }
    size_t stride = width * 4;
    if (height > NSIntegerMax / stride || length != stride * height) {
        return false;
    }

    @autoreleasepool {
        NSPasteboard *pasteboard = (__bridge NSPasteboard *)handle;

        // A null planes pointer makes AppKit allocate and own the pixel storage.
        NSBitmapImageRep *bitmap =
            [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                   pixelsWide:(NSInteger)width
                                                   pixelsHigh:(NSInteger)height
                                                bitsPerSample:8
                                              samplesPerPixel:4
                                                     hasAlpha:YES
                                                     isPlanar:NO
                                               colorSpaceName:NSDeviceRGBColorSpace
                                                 bitmapFormat:NSBitmapFormatAlphaNonpremultiplied
                                                  bytesPerRow:(NSInteger)stride
                                                 bitsPerPixel:32];
        unsigned char *destination = bitmap.bitmapData;
        if (destination == NULL) {
            return false;
        }
        memcpy(destination, rgba, length);

        NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(width, height)];
        [image addRepresentation:bitmap];
        [pasteboard clearContents];
        return [pasteboard writeObjects:@[image]];
    }
}
