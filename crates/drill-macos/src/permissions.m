#import <AppKit/AppKit.h>
#include <stdbool.h>

bool drill_macos_pick_folder(const char *starting_folder, char *selected_folder,
                            size_t selected_folder_capacity) {
    if (![NSThread isMainThread]) {
        return false;
    }

    @autoreleasepool {
        NSWindow *previous_window = [NSApplication sharedApplication].keyWindow;
        NSOpenPanel *panel = [NSOpenPanel openPanel];
        panel.message = @"Choose a folder for Drill to search";
        panel.canChooseDirectories = YES;
        panel.canChooseFiles = NO;
        panel.allowsMultipleSelection = NO;
        panel.canCreateDirectories = YES;
        if (starting_folder != NULL) {
            panel.directoryURL = [NSURL fileURLWithFileSystemRepresentation:starting_folder
                                                                isDirectory:YES
                                                              relativeToURL:nil];
        }

        NSModalResponse response = [panel runModal];
        [previous_window makeKeyAndOrderFront:nil];
        return response == NSModalResponseOK &&
               [panel.URL getFileSystemRepresentation:selected_folder
                                            maxLength:selected_folder_capacity];
    }
}
