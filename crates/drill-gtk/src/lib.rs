#![cfg(target_os = "linux")]
#![deny(unsafe_code)]

#[allow(unsafe_code)]
pub mod desktop_theme;
#[allow(unsafe_code)]
pub mod linux_app_catalog;

use std::{
    ffi::{c_char, c_int, c_void, CStr, CString},
    os::unix::ffi::OsStrExt,
    path::Path,
    ptr::NonNull,
    slice,
    sync::Mutex,
    thread::{self, ThreadId},
};

/// A GTK theme icon with tightly packed, unpremultiplied RGBA pixels.
pub struct Icon {
    pub width: u32,
    pub height: u32,
    pub pixels: Vec<u8>,
}

#[repr(C)]
struct NativePixels {
    width: c_int,
    height: c_int,
    stride: c_int,
    channels: c_int,
    len: usize,
    data: *const u8,
}

#[allow(unsafe_code)]
unsafe extern "C" {
    fn drill_gtk_init() -> c_int;
    fn drill_gtk_load_icon(name: *const c_char, size: c_int) -> *mut c_void;
    fn drill_gtk_load_file_icon(
        path: *const c_char,
        size: c_int,
        filename_only: c_int,
    ) -> *mut c_void;
    fn drill_gtk_pixbuf_pixels(pixbuf: *mut c_void) -> NativePixels;
    fn drill_gtk_release_pixbuf(pixbuf: *mut c_void);
    fn drill_gtk_open_with(path: *const c_char) -> *mut c_char;
    fn drill_gtk_free_error(message: *mut c_char);
}

#[allow(unsafe_code)]
fn init() -> Result<(), String> {
    static OWNER: Mutex<Option<ThreadId>> = Mutex::new(None);

    let current = thread::current().id();
    let mut owner = OWNER.lock().unwrap();
    if let Some(owner) = *owner {
        return if owner == current {
            Ok(())
        } else {
            Err("GTK must be called on the UI thread".into())
        };
    }

    // SAFETY: the mutex serializes initialization and only the initializing
    // thread can use GTK once its default GLib context has been acquired.
    if unsafe { drill_gtk_init() } == 0 {
        return Err("Failed to initialize GTK".into());
    }
    *owner = Some(current);
    Ok(())
}

pub fn get_file_icon(path: &Path, size: u16) -> Option<Icon> {
    file_icon(path, size, false)
}

pub fn mime_type_icon(sample: &Path, size: u16) -> Option<Icon> {
    file_icon(sample, size, true)
}

#[allow(unsafe_code)]
fn file_icon(path: &Path, size: u16, filename_only: bool) -> Option<Icon> {
    init().ok()?;
    let path = CString::new(path.as_os_str().as_bytes()).ok()?;
    // SAFETY: GTK is initialized on this thread. The path is a live C string.
    let raw = unsafe {
        drill_gtk_load_file_icon(path.as_ptr(), i32::from(size), i32::from(filename_only))
    };
    Pixbuf(NonNull::new(raw)?).icon()
}

#[allow(unsafe_code)]
pub fn themed_icon<'a>(mut names: impl Iterator<Item = &'a str>, size: u16) -> Option<Icon> {
    init().ok()?;
    names.find_map(|name| {
        let name = CString::new(name).ok()?;
        // SAFETY: GTK is initialized on this thread. The name is a live C string.
        let raw = unsafe { drill_gtk_load_icon(name.as_ptr(), i32::from(size)) };
        Pixbuf(NonNull::new(raw)?).icon()
    })
}

struct Pixbuf(NonNull<c_void>);

impl Pixbuf {
    #[allow(unsafe_code)]
    fn icon(&self) -> Option<Icon> {
        // SAFETY: self owns a live GdkPixbuf reference returned by the shim.
        let pixels = unsafe { drill_gtk_pixbuf_pixels(self.0.as_ptr()) };
        if pixels.data.is_null() || pixels.len > isize::MAX as usize {
            return None;
        }
        // SAFETY: GdkPixbuf supplies immutable pixel storage and its byte length
        // together. The pixbuf remains alive until the packed copy is complete.
        let data = unsafe { slice::from_raw_parts(pixels.data, pixels.len) };
        rgba_icon(
            data,
            u32::try_from(pixels.width).ok()?,
            u32::try_from(pixels.height).ok()?,
            usize::try_from(pixels.stride).ok()?,
            usize::try_from(pixels.channels).ok()?,
        )
    }
}

impl Drop for Pixbuf {
    #[allow(unsafe_code)]
    fn drop(&mut self) {
        // SAFETY: this is the unique owner of this GdkPixbuf reference.
        unsafe { drill_gtk_release_pixbuf(self.0.as_ptr()) };
    }
}

fn rgba_icon(data: &[u8], width: u32, height: u32, stride: usize, channels: usize) -> Option<Icon> {
    if width == 0 || height == 0 || !matches!(channels, 3 | 4) {
        return None;
    }
    let row_len = (width as usize).checked_mul(channels)?;
    if stride < row_len {
        return None;
    }
    let needed = (height as usize - 1)
        .checked_mul(stride)?
        .checked_add(row_len)?;
    if data.len() < needed {
        return None;
    }

    let expected = (width as usize)
        .checked_mul(height as usize)?
        .checked_mul(4)?;
    let mut pixels = Vec::new();
    pixels.try_reserve_exact(expected).ok()?;
    for row in data.chunks(stride).take(height as usize) {
        let row = &row[..row_len];
        if channels == 4 {
            pixels.extend_from_slice(row);
        } else {
            for rgb in row.as_chunks::<3>().0 {
                pixels.extend_from_slice(&[rgb[0], rgb[1], rgb[2], 255]);
            }
        }
    }
    Some(Icon {
        width,
        height,
        pixels,
    })
}

#[allow(unsafe_code)]
pub fn open_with(path: &Path) -> Result<(), String> {
    init()?;
    let path = CString::new(path.as_os_str().as_bytes()).map_err(|error| error.to_string())?;
    // SAFETY: GTK is initialized on this thread. The path is a live C string.
    let error = unsafe { drill_gtk_open_with(path.as_ptr()) };
    if error.is_null() {
        return Ok(());
    }
    // SAFETY: the shim returned an owned NUL-terminated error message.
    let message = unsafe { CStr::from_ptr(error) }
        .to_string_lossy()
        .into_owned();
    // SAFETY: this is the single release of the shim's allocated message.
    unsafe { drill_gtk_free_error(error) };
    Err(message)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn converts_rgb_rows_with_padding_to_packed_rgba() {
        let icon = rgba_icon(&[1, 2, 3, 0, 4, 5, 6], 1, 2, 4, 3).unwrap();
        assert_eq!((icon.width, icon.height), (1, 2));
        assert_eq!(icon.pixels, [1, 2, 3, 255, 4, 5, 6, 255]);
    }

    #[test]
    fn preserves_alpha_and_ignores_rgba_row_padding() {
        let icon = rgba_icon(&[1, 2, 3, 4, 0, 0, 0, 0, 5, 6, 7, 8], 1, 2, 8, 4).unwrap();
        assert_eq!((icon.width, icon.height), (1, 2));
        assert_eq!(icon.pixels, [1, 2, 3, 4, 5, 6, 7, 8]);
    }

    #[test]
    fn rejects_truncated_pixel_buffers_and_invalid_strides() {
        assert!(rgba_icon(&[0; 6], 1, 2, 4, 3).is_none());
        assert!(rgba_icon(&[0; 8], 2, 1, 4, 3).is_none());
    }
}
