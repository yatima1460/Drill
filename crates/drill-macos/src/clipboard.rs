use std::ffi::c_void;
use std::ptr::NonNull;

type TextSink = unsafe extern "C" fn(*mut c_void, *const u8, usize);

unsafe extern "C" {
    fn drill_macos_clipboard_open() -> *mut c_void;
    fn drill_macos_clipboard_close(handle: *mut c_void);
    fn drill_macos_clipboard_read_text(handle: *mut c_void, context: *mut c_void, sink: TextSink);
    fn drill_macos_clipboard_write_text(
        handle: *mut c_void,
        bytes: *const u8,
        length: usize,
    ) -> bool;
    fn drill_macos_clipboard_write_rgba(
        handle: *mut c_void,
        rgba: *const u8,
        length: usize,
        width: usize,
        height: usize,
    ) -> bool;
}

/// An owned handle to the macOS pasteboard.
pub struct Pasteboard(NonNull<c_void>);

impl Pasteboard {
    /// Open the general pasteboard if the pasteboard service is available.
    pub fn general() -> Option<Self> {
        // SAFETY: The bridge returns an owned handle or null.
        NonNull::new(unsafe { drill_macos_clipboard_open() }).map(Self)
    }

    /// Read the first plain text item.
    pub fn text(&self) -> Option<String> {
        unsafe extern "C" fn receive_text(context: *mut c_void, bytes: *const u8, length: usize) {
            if length > isize::MAX as usize {
                return;
            }
            // SAFETY: The bridge calls this synchronously with our context and a
            // UTF-8 byte slice owned by its NSData. An empty NSData may have a null pointer.
            unsafe {
                let text = &mut *context.cast::<Option<String>>();
                let bytes = if length == 0 {
                    &[]
                } else {
                    std::slice::from_raw_parts(bytes, length)
                };
                *text = Some(String::from_utf8_lossy(bytes).into_owned());
            }
        }

        let mut text: Option<String> = None;
        // SAFETY: The handle, callback, and result slot stay valid for the synchronous call.
        unsafe {
            drill_macos_clipboard_read_text(self.0.as_ptr(), (&raw mut text).cast(), receive_text);
        }
        text
    }

    /// Replace the clipboard with UTF-8 text.
    pub fn set_text(&self, text: &str) -> bool {
        // SAFETY: The live handle and UTF-8 bytes stay valid through the call.
        unsafe { drill_macos_clipboard_write_text(self.0.as_ptr(), text.as_ptr(), text.len()) }
    }

    /// Replace the clipboard with a tightly packed image with straight RGBA channels.
    pub fn set_rgba(&self, width: usize, height: usize, rgba: &[u8]) -> bool {
        // SAFETY: The live handle and slice stay valid through the call. The
        // bridge checks the dimensions and length before reading the bytes.
        unsafe {
            drill_macos_clipboard_write_rgba(
                self.0.as_ptr(),
                rgba.as_ptr(),
                rgba.len(),
                width,
                height,
            )
        }
    }
}

impl Drop for Pasteboard {
    fn drop(&mut self) {
        // SAFETY: This instance uniquely owns the native retain.
        unsafe { drill_macos_clipboard_close(self.0.as_ptr()) };
    }
}
