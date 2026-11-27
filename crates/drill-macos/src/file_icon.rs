use std::path::Path;

unsafe extern "C" {
    fn drill_macos_file_icon(
        path: *const u8,
        path_length: usize,
        size: u16,
        pixels: *mut u8,
        capacity: usize,
    ) -> i32;
}

/// Returns a square icon in packed, premultiplied RGBA pixels.
pub fn file_icon(path: &Path, size: u16) -> Option<Vec<u8>> {
    if !(1..=256).contains(&size) {
        return None;
    }
    let path = path.canonicalize().ok()?;
    let path = path.to_str()?.as_bytes();
    let mut pixels = vec![0; usize::from(size).pow(2) * 4];
    // SAFETY: Both pointers reference live slices of the supplied lengths.
    // The native helper bounds its write to the pixel buffer and retains no pointers.
    let ok = unsafe {
        drill_macos_file_icon(
            path.as_ptr(),
            path.len(),
            size,
            pixels.as_mut_ptr(),
            pixels.len(),
        )
    };
    (ok != 0).then_some(pixels)
}
