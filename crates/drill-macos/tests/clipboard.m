#import <AppKit/AppKit.h>
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <sysexits.h>

#include "../src/clipboard.h"

typedef struct {
    const uint8_t *expected;
    size_t length;
    bool called;
} TextProbe;

static void check_text(void *context, const uint8_t *bytes, size_t length) {
    TextProbe *probe = context;
    assert(!probe->called);
    assert(length == probe->length);
    assert(length == 0 || memcmp(bytes, probe->expected, length) == 0);
    probe->called = true;
}

int main(void) {
    @autoreleasepool {
        NSPasteboard *pasteboard = [NSPasteboard pasteboardWithUniqueName];
        if (pasteboard == nil) {
            fputs("The macOS pasteboard service is unavailable in this session.\n", stderr);
            return EX_UNAVAILABLE;
        }
        void *handle = (__bridge void *)pasteboard;
        const uint8_t text[] = "žlutý 🌳\r\nsecond line";
        const uint8_t rgba[] = {255, 0, 0, 255, 0, 255, 0, 127};

        assert(drill_macos_clipboard_write_text(handle, text, sizeof(text) - 1));
        assert(!drill_macos_clipboard_write_rgba(handle, rgba, sizeof(rgba) - 1, 2, 1));
        assert(!drill_macos_clipboard_write_rgba(handle, rgba, sizeof(rgba), SIZE_MAX, 1));
        TextProbe probe = {text, sizeof(text) - 1, false};
        drill_macos_clipboard_read_text(handle, &probe, check_text);
        assert(probe.called);

        assert(drill_macos_clipboard_write_text(handle, text, 0));
        probe = (TextProbe){NULL, 0, false};
        drill_macos_clipboard_read_text(handle, &probe, check_text);
        assert(probe.called);

        assert(drill_macos_clipboard_write_rgba(handle, rgba, sizeof(rgba), 2, 1));
        probe.called = false;
        drill_macos_clipboard_read_text(handle, &probe, check_text);
        assert(!probe.called);
        NSData *tiff = [pasteboard dataForType:NSPasteboardTypeTIFF];
        assert(tiff != nil);
        NSBitmapImageRep *bitmap = [NSBitmapImageRep imageRepWithData:tiff];
        assert(bitmap.pixelsWide == 2 && bitmap.pixelsHigh == 1);
        assert(bitmap.samplesPerPixel == 4);
        NSUInteger samples[4] = {0};
        [bitmap getPixel:samples atX:0 y:0];
        assert(samples[3] == 255);
        [bitmap getPixel:samples atX:1 y:0];
        assert(samples[3] == 127);

        [pasteboard clearContents];
        assert(([pasteboard writeObjects:@[@"first item", @"second item"]]));
        const uint8_t first[] = "first item";
        probe = (TextProbe){first, sizeof(first) - 1, false};
        drill_macos_clipboard_read_text(handle, &probe, check_text);
        assert(probe.called);
        [pasteboard releaseGlobally];
    }
    puts("Private macOS pasteboard text and image tests passed.");
    return 0;
}
