use std::ffi::c_void;
use std::num::NonZeroIsize;

unsafe extern "C" {
    fn drill_windows_clipboard_read_text(
        context: *mut c_void,
        accept: unsafe extern "C" fn(*mut c_void, *const u16, usize),
    );
    fn drill_windows_clipboard_write_text(
        owner: *mut c_void,
        text: *const u16,
        length: usize,
    ) -> bool;
    fn drill_windows_clipboard_write_image(
        owner: *mut c_void,
        width: i32,
        height: i32,
        rgba: *const u8,
        rgba_size: usize,
        png: *const u8,
        png_size: usize,
    ) -> bool;
}

/// Copy the system clipboard's Unicode text while Windows keeps its buffer locked.
pub fn read_text() -> Option<String> {
    unsafe extern "C" fn accept(context: *mut c_void, text: *const u16, length: usize) {
        // SAFETY: the caller passes a live Option<String> and a bounded locked UTF-16 buffer.
        unsafe {
            *context.cast::<Option<String>>() = Some(String::from_utf16_lossy(
                std::slice::from_raw_parts(text, length),
            ));
        }
    }

    let mut text: Option<String> = None;
    // SAFETY: the callback uses the live context only during this synchronous call.
    unsafe { drill_windows_clipboard_read_text((&raw mut text).cast(), accept) };
    text
}

/// Copy text into a system-owned clipboard allocation associated with this Win32 window.
pub fn write_text(owner: NonZeroIsize, text: &str) -> bool {
    let text: Vec<u16> = text.encode_utf16().chain([0]).collect();
    // SAFETY: text is a live NUL-terminated buffer. The native adapter validates the HWND.
    unsafe {
        drill_windows_clipboard_write_text(owner.get() as *mut c_void, text.as_ptr(), text.len())
    }
}

/// Publish a straight RGBA bitmap and its optional PNG representation.
pub fn write_rgba(
    owner: NonZeroIsize,
    width: usize,
    height: usize,
    rgba: &[u8],
    png: Option<&[u8]>,
) -> bool {
    let (Ok(native_width), Ok(native_height)) = (i32::try_from(width), i32::try_from(height))
    else {
        return false;
    };
    if width == 0
        || height == 0
        || width
            .checked_mul(height)
            .and_then(|pixels| pixels.checked_mul(4))
            != Some(rgba.len())
        || u32::try_from(rgba.len()).is_err()
    {
        return false;
    }

    let png = png.unwrap_or_default();
    // SAFETY: the validated dimensions match rgba, both buffers are live for the call, and the
    // native adapter verifies the HWND before acquiring clipboard ownership.
    unsafe {
        drill_windows_clipboard_write_image(
            owner.get() as *mut c_void,
            native_width,
            native_height,
            rgba.as_ptr(),
            rgba.len(),
            png.as_ptr(),
            png.len(),
        )
    }
}
