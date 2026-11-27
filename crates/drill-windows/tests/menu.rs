#![cfg(all(windows, feature = "menu"))]

mod support;

use drill_windows::menu::{Command, Menu};
use std::cell::RefCell;
use std::mem::size_of;
use std::ptr::null_mut;
use std::rc::Rc;
use support::{Handle, Window};

// MENUINFO from winuser.h; use the SDK to inspect how installed submenus notify the window.
#[repr(C)]
struct MenuInfo {
    size: u32,
    mask: u32,
    style: u32,
    max_height: u32,
    background: Handle,
    context_help_id: u32,
    data: usize,
}

#[link(name = "user32")]
unsafe extern "system" {
    fn GetMenu(window: Handle) -> Handle;
    fn SetMenu(window: Handle, menu: Handle) -> i32;
    fn CreateMenu() -> Handle;
    fn GetSubMenu(menu: Handle, position: i32) -> Handle;
    fn GetMenuItemID(menu: Handle, position: i32) -> u32;
    fn GetMenuState(menu: Handle, item: u32, flags: u32) -> u32;
    fn GetMenuInfo(menu: Handle, info: *mut MenuInfo) -> i32;
    fn SendMessageW(window: Handle, message: u32, wparam: usize, lparam: isize) -> isize;
}

const WM_MENUCOMMAND: u32 = 0x0126;

fn submenu(bar: Handle, position: i32) -> Handle {
    // SAFETY: The fixture owns a live window with this native menu bar attached.
    let item = unsafe { GetSubMenu(bar, position) };
    assert!(!item.is_null());
    let mut info = MenuInfo {
        size: size_of::<MenuInfo>() as u32,
        mask: 0x10, // MIM_STYLE
        style: 0,
        max_height: 0,
        background: null_mut(),
        context_help_id: 0,
        data: 0,
    };
    // SAFETY: The submenu is live and info is the correctly sized MENUINFO output.
    assert_ne!(unsafe { GetMenuInfo(item, &mut info) }, 0);
    assert_ne!(info.style & 0x0800_0000, 0, "MNS_NOTIFYBYPOS absent");
    item
}

fn enabled(menu: Handle, position: u32) -> bool {
    // SAFETY: The menu belongs to the fixture; MF_BYPOSITION selects its indexed item.
    let state = unsafe { GetMenuState(menu, position, 0x0400) };
    assert_ne!(state, u32::MAX);
    state & 3 == 0 // Neither MF_DISABLED nor MF_GRAYED.
}

fn select(window: &Window, menu: Handle, position: usize) {
    // SAFETY: Synchronous same-thread message with the selected position and menu handle.
    unsafe {
        SendMessageW(
            window.0.get() as Handle,
            WM_MENUCOMMAND,
            position,
            menu as isize,
        )
    };
}

#[test]
fn native_menu_routes_only_its_enabled_commands_and_restores_previous_menu() {
    let window = Window::hidden();
    let hwnd = window.0.get() as Handle;
    // SAFETY: The original menu becomes owned by the window and is restored before teardown.
    let previous = unsafe { CreateMenu() };
    assert!(!previous.is_null());
    // SAFETY: The hidden top-level window and new menu belong to this thread.
    assert_ne!(unsafe { SetMenu(hwnd, previous) }, 0);
    let commands = Rc::new(RefCell::new(Vec::new()));
    let record = Rc::clone(&commands);
    // SAFETY: The hidden window belongs to this thread and remains live throughout dispatch.
    let menu = unsafe { Menu::install(window.0, move |command| record.borrow_mut().push(command)) }
        .expect("menu installation");
    // SAFETY: The hidden window has the newly installed bar.
    let bar = unsafe { GetMenu(hwnd) };
    assert_ne!(bar, previous);
    // SAFETY: A second installation on the same live window must preserve the first callback.
    assert!(unsafe { Menu::install(window.0, |_| panic!("duplicate menu dispatched")) }.is_none());
    let search = submenu(bar, 2);
    let settings = submenu(bar, 3);
    let help = submenu(bar, 4);

    menu.set_enabled(false, false);
    assert!(!enabled(search, 1) && !enabled(bar, 3));
    select(&window, search, 1);
    select(&window, settings, 0);
    select(&window, search, 2); // Continue is disabled until a page can resume.
    select(&window, help, 1);
    select(&window, previous, 0);
    // SAFETY: An unrelated WM_COMMAND must pass through to the hidden window.
    unsafe { SendMessageW(hwnd, 0x0111, 1, 0) };
    assert!(commands.borrow().is_empty());

    menu.set_enabled(true, true);
    assert!(enabled(search, 1) && enabled(bar, 3));
    // SAFETY: The help popup has one native menu item at position zero.
    let syntax_id = unsafe { GetMenuItemID(help, 0) };
    assert_ne!(syntax_id, u32::MAX);
    // SAFETY: Control notifications carry a child HWND, while accelerators have a null lParam.
    unsafe {
        SendMessageW(hwnd, 0x0111, syntax_id as usize, hwnd as isize);
        SendMessageW(hwnd, 0x0111, (syntax_id | 0x1_0000) as usize, 0);
    }
    select(&window, submenu(bar, 0), 0);
    select(&window, submenu(bar, 1), 2); // Separator has no command.
    select(&window, submenu(bar, 1), 5);
    select(&window, search, 0);
    select(&window, search, 1);
    menu.set_command_enabled(Command::Continue, true);
    select(&window, search, 2);
    select(&window, settings, 0);
    // SAFETY: This synchronous invocation uses the registered Win32 command identifier.
    unsafe { SendMessageW(hwnd, 0x0111, syntax_id as usize, 0) };
    assert_eq!(
        *commands.borrow(),
        [
            Command::Syntax,
            Command::OpenSelection,
            Command::Paste,
            Command::Find,
            Command::Stop,
            Command::Continue,
            Command::Interface,
            Command::Syntax
        ]
    );
    drop(menu);
    // SAFETY: The hidden window remains live and resumes ownership of the original menu.
    assert_eq!(unsafe { GetMenu(hwnd) }, previous);
    select(&window, previous, 0);
    assert_eq!(commands.borrow().len(), 8);
}

#[test]
fn native_menu_can_outlive_its_window_or_be_dropped_inside_dispatch() {
    let window = Window::hidden();
    // SAFETY: Installation and window destruction occur on the same thread.
    let menu = unsafe { Menu::install(window.0, |_| {}) }.unwrap();
    drop(window);
    // Subsequent menu operations must also tolerate the destroyed window.
    let replacement = Window::hidden();
    menu.set_enabled(true, true);
    drop(menu);
    // SAFETY: The replacement is a live window with no menu.
    assert!(unsafe { GetMenu(replacement.0.get() as Handle) }.is_null());

    let slot: Rc<RefCell<Option<Menu>>> = Rc::default();
    let callback_slot = Rc::downgrade(&slot);
    // SAFETY: The replacement window remains live while the callback drops its own menu.
    *slot.borrow_mut() = unsafe {
        Menu::install(replacement.0, move |_| {
            callback_slot.upgrade().unwrap().borrow_mut().take();
        })
    };
    assert!(slot.borrow().is_some());
    // SAFETY: GetMenu borrows this private window's installed menu.
    let bar = unsafe { GetMenu(replacement.0.get() as Handle) };
    select(&replacement, submenu(bar, 4), 0);
    assert!(slot.borrow().is_none());
    // SAFETY: The private window stays live after the menu callback has returned.
    assert!(unsafe { GetMenu(replacement.0.get() as Handle) }.is_null());
}
