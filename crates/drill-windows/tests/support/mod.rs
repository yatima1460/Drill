use std::ffi::c_void;
use std::io;
use std::num::NonZeroIsize;
use std::ptr::null_mut;

pub type Handle = *mut c_void;

#[link(name = "user32")]
unsafe extern "system" {
    fn CreateWindowExW(
        extended_style: u32,
        class: *const u16,
        name: *const u16,
        style: u32,
        x: i32,
        y: i32,
        width: i32,
        height: i32,
        parent: Handle,
        menu: Handle,
        instance: Handle,
        param: Handle,
    ) -> Handle;
    fn DestroyWindow(window: Handle) -> i32;
}

pub struct Window(pub NonZeroIsize);

impl Window {
    pub fn hidden() -> Self {
        let class: Vec<u16> = "STATIC\0".encode_utf16().collect();
        // SAFETY: The terminated class names a system control. The window has no visible style.
        let window = unsafe {
            CreateWindowExW(
                0,
                class.as_ptr(),
                std::ptr::null(),
                0,
                0,
                0,
                1,
                1,
                null_mut(),
                null_mut(),
                null_mut(),
                null_mut(),
            )
        };
        Self(NonZeroIsize::new(window as isize).unwrap_or_else(|| {
            panic!(
                "could not create the hidden test window: {}",
                io::Error::last_os_error()
            )
        }))
    }
}

impl Drop for Window {
    fn drop(&mut self) {
        // SAFETY: This thread created and owns this live window.
        unsafe { DestroyWindow(self.0.get() as Handle) };
    }
}
