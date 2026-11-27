//! The menu bar attached to Drill's main Win32 window.
use std::ffi::{c_int, c_void};
use std::num::NonZeroIsize;
use std::ptr::NonNull;
use std::rc::Rc;

unsafe extern "C" {
    fn drill_windows_menu_install(
        hwnd: *mut c_void,
        callback: unsafe extern "C" fn(*const c_void, u8),
        context: *const c_void,
    ) -> *mut c_void;
    fn drill_windows_menu_enable(handle: *mut c_void, command: c_int, enabled: bool);
    fn drill_windows_menu_set_enabled(handle: *mut c_void, stop: bool, settings: bool);
    fn drill_windows_menu_set_dark(handle: *mut c_void, dark: bool);
    fn drill_windows_menu_remove(handle: *mut c_void);
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
#[repr(i32)]
pub enum Command {
    Stop,
    Interface,
    Syntax,
    OpenSelection,
    CloseWindow,
    Undo,
    Redo,
    Cut,
    Copy,
    Paste,
    SelectAll,
    Find,
    Continue,
}

pub struct Menu {
    handle: NonNull<c_void>,
    // The subclass borrows this stable address until the native handle is removed.
    _callback: Box<Rc<dyn Fn(Command)>>,
}

impl Menu {
    /// Attach Drill's menu on the thread that owns the window.
    ///
    /// # Safety
    /// `hwnd` must identify a live top-level window owned by the caller. If an
    /// existing menu is installed, its owner must keep it live until restored.
    pub unsafe fn install(
        hwnd: NonZeroIsize,
        callback: impl Fn(Command) + 'static,
    ) -> Option<Self> {
        let callback: Box<Rc<dyn Fn(Command)>> = Box::new(Rc::new(callback));
        let context = (&raw const *callback).cast();
        // SAFETY: The caller owns the live window, and the box remains at this address.
        let raw = unsafe { drill_windows_menu_install(hwnd.get() as _, dispatch, context) };
        Some(Self {
            handle: NonNull::new(raw)?,
            _callback: callback,
        })
    }

    pub fn set_dark(&self, dark: bool) {
        // SAFETY: This menu owns the UI-thread handle, including during a theme change.
        unsafe { drill_windows_menu_set_dark(self.handle.as_ptr(), dark) };
    }

    pub fn set_command_enabled(&self, command: Command, enabled: bool) {
        // SAFETY: The native menu is owned by this thread, and command is a valid menu item.
        unsafe { drill_windows_menu_enable(self.handle.as_ptr(), command as c_int, enabled) };
    }

    pub fn set_enabled(&self, stop: bool, settings: bool) {
        // SAFETY: The menu is confined to its installing thread and owns the handle.
        unsafe { drill_windows_menu_set_enabled(self.handle.as_ptr(), stop, settings) };
    }
}

impl Drop for Menu {
    fn drop(&mut self) {
        // SAFETY: Native removal detaches the callback before its box is dropped.
        unsafe { drill_windows_menu_remove(self.handle.as_ptr()) };
    }
}

unsafe extern "C" fn dispatch(context: *const c_void, command: u8) {
    let command = match command {
        0 => Command::Stop,
        1 => Command::Interface,
        2 => Command::Syntax,
        3 => Command::OpenSelection,
        4 => Command::CloseWindow,
        5 => Command::Undo,
        6 => Command::Redo,
        7 => Command::Cut,
        8 => Command::Copy,
        9 => Command::Paste,
        10 => Command::SelectAll,
        11 => Command::Find,
        12 => Command::Continue,
        _ => return,
    };
    // SAFETY: The native subclass borrows the boxed Rc only while installed.
    // The cloned Rc also permits the callback to drop its own menu.
    let callback = unsafe { Rc::clone(&*context.cast::<Rc<dyn Fn(Command)>>()) };
    callback(command);
}
