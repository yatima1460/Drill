use std::{any::Any, ffi::c_void, ptr::NonNull, rc::Rc};

type Callback = unsafe extern "C" fn(*const c_void, u8);

#[allow(unsafe_code)]
unsafe extern "C" {
    fn drill_menu_install(callback: Callback, context: *const c_void) -> *mut c_void;
    fn drill_menu_set_enabled(handle: *mut c_void, stop: bool, settings: bool);
    fn drill_menu_remove(handle: *mut c_void);
}

pub enum Command {
    Stop,
    Interface,
    Syntax,
    Permissions,
}

pub struct Menu {
    handle: NonNull<c_void>,
    _callback: Rc<dyn Any>,
}

impl Menu {
    /// Adds Drill's menus to the main menu installed by winit.
    ///
    /// The callback runs on the main thread. Installation fails from another
    /// thread, before the application's main menu is available, or while
    /// another Drill menu is installed.
    #[allow(unsafe_code)]
    pub fn install<F: Fn(Command) + 'static>(callback: F) -> Option<Self> {
        // AppKit borrows the outer Rc as its context. A clone of the inner
        // Rc keeps the callback running if its invocation closes the menu.
        let callback = Rc::new(Rc::new(callback));
        let context = Rc::as_ptr(&callback).cast();
        // SAFETY: AppKit calls dispatch with this context only while Menu keeps
        // the allocation alive. Native install checks for the main thread.
        let handle = unsafe { drill_menu_install(dispatch::<F>, context) };
        Some(Self {
            handle: NonNull::new(handle)?,
            _callback: callback,
        })
    }

    #[allow(unsafe_code)]
    pub fn set_enabled(&self, stop: bool, settings: bool) {
        // SAFETY: This main-thread-only type owns the installed handle.
        unsafe { drill_menu_set_enabled(self.handle.as_ptr(), stop, settings) };
    }
}

impl Drop for Menu {
    #[allow(unsafe_code)]
    fn drop(&mut self) {
        // SAFETY: This is the only owner of the handle. Removal disables
        // dispatch before the callback allocation is released.
        unsafe { drill_menu_remove(self.handle.as_ptr()) };
    }
}

#[allow(unsafe_code)]
unsafe extern "C" fn dispatch<F: Fn(Command)>(context: *const c_void, command: u8) {
    let command = match command {
        0 => Command::Stop,
        1 => Command::Interface,
        2 => Command::Syntax,
        3 => Command::Permissions,
        _ => return,
    };
    // SAFETY: Menu::install pairs this dispatch function with a pointer to the
    // matching Rust callback and keeps the callback alive until removal.
    // Clone before calling user code, which can close the menu reentrantly.
    let callback = Rc::clone(unsafe { &*context.cast::<Rc<F>>() });
    callback(command);
}
