#import <AppKit/AppKit.h>
#include <stdbool.h>
#include <stdint.h>

typedef void (*DrillMenuCallback)(const void *context, uint8_t command);

typedef NS_ENUM(uint8_t, DrillMenuCommand) {
    DrillMenuStop,
    DrillMenuInterface,
    DrillMenuSyntax,
    DrillMenuPermissions,
};

@interface DrillMacMenu : NSObject {
@public
    DrillMenuCallback callback;
    const void *context;
    BOOL autoenablesItems;
    NSMenu *mainMenu;
    NSMenu *previousHelpMenu;
    NSMenuItem *searchItem;
    NSMenuItem *settingsItem;
    NSMenuItem *helpItem;
    NSMenuItem *stopItem;
}

- (void)dispatchAction:(NSMenuItem *)sender;

@end

@implementation DrillMacMenu

- (void)dispatchAction:(NSMenuItem *)sender {
    if (callback != NULL) {
        callback(context, (uint8_t)sender.tag);
    }
}

@end

// NSApplication has one shared main menu, even when it has multiple windows.
static __weak DrillMacMenu *installedMenu;

static NSMenuItem *submenu(NSString *title) {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:NULL keyEquivalent:@""];
    item.submenu = [[NSMenu alloc] initWithTitle:title];
    item.submenu.autoenablesItems = NO;
    return item;
}

static NSMenuItem *action(
    DrillMacMenu *target, NSString *title, DrillMenuCommand command
) {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title
                                               action:@selector(dispatchAction:)
                                        keyEquivalent:@""];
    item.target = target;
    item.tag = command;
    return item;
}

void *drill_menu_install(DrillMenuCallback callback, const void *context) {
    if (![NSThread isMainThread]) {
        return NULL;
    }
    @autoreleasepool {
        // Winit installs the standard application menu before creating the window.
        NSApplication *app = NSApplication.sharedApplication;
        NSMenu *mainMenu = app.mainMenu;
        if (mainMenu == nil || installedMenu != nil) {
            return NULL;
        }

        DrillMacMenu *menu = [DrillMacMenu new];
        installedMenu = menu;
        menu->callback = callback;
        menu->context = context;
        menu->mainMenu = mainMenu;
        menu->autoenablesItems = mainMenu.autoenablesItems;
        menu->previousHelpMenu = app.helpMenu;

        menu->searchItem = submenu(@"Search");
        menu->stopItem = action(menu, @"Stop", DrillMenuStop);
        menu->stopItem.enabled = NO;
        [menu->searchItem.submenu addItem:menu->stopItem];

        menu->settingsItem = submenu(@"Settings");
        [menu->settingsItem.submenu addItem:action(menu, @"Interface…", DrillMenuInterface)];
        [menu->settingsItem.submenu addItem:action(menu, @"Permissions…", DrillMenuPermissions)];

        menu->helpItem = submenu(@"Help");
        [menu->helpItem.submenu addItem:action(menu, @"Syntax", DrillMenuSyntax)];

        // The application submenu keeps its own validation and responder chain.
        mainMenu.autoenablesItems = NO;
        [mainMenu addItem:menu->searchItem];
        [mainMenu addItem:menu->settingsItem];
        [mainMenu addItem:menu->helpItem];
        app.helpMenu = menu->helpItem.submenu;
        return (__bridge_retained void *)menu;
    }
}

void drill_menu_set_enabled(void *handle, bool stop, bool settings) {
    DrillMacMenu *menu = (__bridge DrillMacMenu *)handle;
    if (menu->stopItem.enabled != stop) {
        menu->stopItem.enabled = stop;
    }
    if (menu->settingsItem.enabled != settings) {
        menu->settingsItem.enabled = settings;
    }
}

void drill_menu_remove(void *handle) {
    @autoreleasepool {
        DrillMacMenu *menu = (__bridge_transfer DrillMacMenu *)handle;
        menu->callback = NULL;
        NSApplication *app = NSApplication.sharedApplication;
        if (app.helpMenu == menu->helpItem.submenu) {
            app.helpMenu = menu->previousHelpMenu;
        }
        for (NSMenuItem *item in @[menu->searchItem, menu->settingsItem, menu->helpItem]) {
            if ([menu->mainMenu indexOfItem:item] >= 0) {
                [menu->mainMenu removeItem:item];
            }
        }
        menu->mainMenu.autoenablesItems = menu->autoenablesItems;
        installedMenu = nil;
    }
}
