use std::ffi::OsStr;
use std::os::unix::ffi::OsStrExt;
use std::path::Path;

/// Decode one file on the calling worker thread. See DrillIcon.h.
///
/// # Safety
/// For non-null pointers and valid lengths, `path` must be readable for
/// `path_len` bytes and `rgba` writable for `rgba_len` bytes. Neither may
/// overlap or be modified concurrently during the call.
#[no_mangle]
pub unsafe extern "C" fn drill_decode_icon(
    path: *const u8,
    path_len: usize,
    rgba: *mut u8,
    rgba_len: usize,
) -> bool {
    if path.is_null()
        || rgba.is_null()
        || !(1..=4096).contains(&path_len)
        || rgba_len != drill_icons::RGBA_BYTES
    {
        return false;
    }
    // SAFETY: the caller provides path_len readable bytes, bounded above.
    let path = unsafe { std::slice::from_raw_parts(path, path_len) };
    let Some(pixels) = drill_icons::decode(Path::new(OsStr::from_bytes(path)), || true) else {
        return false;
    };
    // SAFETY: on success the decoder returns one fixed-size RGBA image. The
    // caller's output is writable for exactly that size and belongs to the caller.
    let output = unsafe { std::slice::from_raw_parts_mut(rgba, rgba_len) };
    output.copy_from_slice(&pixels);
    true
}

#[cfg(test)]
mod tests {
    use super::*;

    fn decode_fixture(path: &Path, output: &mut [u8]) -> bool {
        let bytes = path.as_os_str().as_bytes();
        // SAFETY: both slices live throughout the call and do not overlap.
        unsafe {
            drill_decode_icon(
                bytes.as_ptr(),
                bytes.len(),
                output.as_mut_ptr(),
                output.len(),
            )
        }
    }

    #[test]
    fn returns_wasm_pixels_for_both_file_formats() {
        let tools = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../tools");
        let mut output = [0; drill_icons::RGBA_BYTES];
        for fixture in [
            "exe-icon-wasm/tests/fixtures/icon-pe32.exe",
            "appimage-icon-wasm/tests/fixtures/linked-png.AppImage",
        ] {
            assert!(decode_fixture(&tools.join(fixture), &mut output));
            assert_eq!(&output[..4], &[0, 255, 0, 255]);
            output.fill(0);
        }
    }

    #[test]
    fn failed_decodes_leave_output_unchanged() {
        let mut output = [9; drill_icons::RGBA_BYTES];
        let cyclic = Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("../../tools/appimage-icon-wasm/tests/fixtures/cyclic.AppImage");
        assert!(!decode_fixture(&cyclic, &mut output));
        assert!(!decode_fixture(&cyclic, &mut output[..4]));
        assert_eq!(output, [9; drill_icons::RGBA_BYTES]);
    }
}
