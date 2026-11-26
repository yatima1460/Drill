//! Straight-alpha PNG conversion for Drill's bundled artwork on macOS.

#[repr(C)]
struct NativeBytes {
    ptr: *mut u8,
    len: usize,
}

unsafe extern "C" {
    fn drill_macos_png_decode(
        png: *const u8,
        len: usize,
        width: *mut u32,
        height: *mut u32,
    ) -> NativeBytes;
    fn drill_macos_png_encode(rgba: *const u8, len: usize, width: u32, height: u32) -> NativeBytes;
    fn drill_macos_png_free(bytes: *mut u8);
}

impl NativeBytes {
    fn copy(&self) -> Option<Vec<u8>> {
        if self.ptr.is_null() || self.len == 0 || self.len > isize::MAX as usize {
            return None;
        }
        // SAFETY: Each successful native call initializes exactly len bytes.
        // The allocation is owned by self and remains live during the copy.
        Some(unsafe { std::slice::from_raw_parts(self.ptr, self.len) }.to_vec())
    }
}

impl Drop for NativeBytes {
    fn drop(&mut self) {
        // SAFETY: The native bridge returns either a matching allocation or null.
        unsafe { drill_macos_png_free(self.ptr) };
    }
}

/// Decode a bundled 8-bit PNG to dimensions and unassociated RGBA bytes.
pub fn decode_png(png: &[u8]) -> Option<(u32, u32, Vec<u8>)> {
    let (mut width, mut height) = (0, 0);
    // SAFETY: The slice and output addresses remain valid for the call.
    let native =
        unsafe { drill_macos_png_decode(png.as_ptr(), png.len(), &mut width, &mut height) };
    if rgba_len(width, height) != Some(native.len) {
        return None;
    }
    Some((width, height, native.copy()?))
}

/// Encode an app icon from dimensions and unassociated RGBA bytes.
pub fn encode_png(width: u32, height: u32, rgba: &[u8]) -> Option<Vec<u8>> {
    if rgba_len(width, height) != Some(rgba.len()) {
        return None;
    }
    // SAFETY: The native encoder reads only the checked slice during the call.
    unsafe { drill_macos_png_encode(rgba.as_ptr(), rgba.len(), width, height) }.copy()
}

fn rgba_len(width: u32, height: u32) -> Option<usize> {
    let pixels = (width as usize).checked_mul(height as usize)?;
    pixels.checked_mul(4).filter(|&len| len != 0)
}
