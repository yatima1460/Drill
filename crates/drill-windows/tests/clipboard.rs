#![cfg(all(windows, feature = "clipboard"))]

use drill_windows::clipboard;
use std::ffi::c_void;
use std::io;
use std::num::NonZeroIsize;
use std::ptr::null_mut;
use std::time::{Duration, Instant};

type Handle = *mut c_void;
const CF_DIBV5: u32 = 17;
const DIB_HEADER_SIZE: usize = 124;

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
    fn OpenClipboard(window: Handle) -> i32;
    fn CloseClipboard() -> i32;
    fn RegisterClipboardFormatW(name: *const u16) -> u32;
    fn EnumClipboardFormats(format: u32) -> u32;
    fn GetClipboardData(format: u32) -> Handle;
}

#[link(name = "kernel32")]
unsafe extern "system" {
    fn GlobalSize(memory: Handle) -> usize;
    fn GlobalLock(memory: Handle) -> Handle;
    fn GlobalUnlock(memory: Handle) -> i32;
}

struct Window(NonZeroIsize);

impl Window {
    fn hidden() -> Self {
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
                "could not create clipboard owner: {}",
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

struct OpenClipboardGuard;

impl OpenClipboardGuard {
    fn open() -> Self {
        let deadline = Instant::now() + Duration::from_secs(1);
        loop {
            // SAFETY: A null window opens the clipboard for this thread to read.
            if unsafe { OpenClipboard(null_mut()) } != 0 {
                return Self;
            }
            assert!(
                Instant::now() < deadline,
                "could not open clipboard: {}",
                io::Error::last_os_error()
            );
            std::thread::sleep(Duration::from_millis(10));
        }
    }

    fn read(&self, format: u32, len: usize) -> Vec<u8> {
        // SAFETY: This guard holds the clipboard open. These formats store global memory.
        let memory = unsafe { GetClipboardData(format) };
        assert!(!memory.is_null(), "clipboard format {format} is missing");
        // SAFETY: The handle remains valid while the clipboard is open.
        assert!(unsafe { GlobalSize(memory) } >= len);
        // SAFETY: The valid handle may be locked while the clipboard is open.
        let bytes = unsafe { GlobalLock(memory) }.cast::<u8>();
        assert!(!bytes.is_null());
        // SAFETY: The locked block contains at least len bytes.
        let copy = unsafe { std::slice::from_raw_parts(bytes, len) }.to_vec();
        // SAFETY: This releases the successful lock above.
        unsafe { GlobalUnlock(memory) };
        copy
    }
}

impl Drop for OpenClipboardGuard {
    fn drop(&mut self) {
        // SAFETY: The constructor opened the clipboard on this thread.
        unsafe { CloseClipboard() };
    }
}

#[test]
#[ignore = "replaces the system clipboard; run explicitly on a disposable Windows desktop"]
fn clipboard_round_trips_unicode_text_png_and_dib() {
    let owner = Window::hidden();
    let text = "Žlutý 🌳\r\nsecond line";
    assert!(clipboard::write_text(owner.0, text));
    assert_eq!(clipboard::read_text().as_deref(), Some(text));

    let rgba = [
        255, 0, 0, 255, 0, 255, 0, 128, 0, 0, 255, 64, 0x12, 0x34, 0x56, 32,
    ];
    // A 2×2 PNG with the same straight RGBA pixels.
    let png = [
        0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44,
        0x52, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x02, 0x08, 0x06, 0x00, 0x00, 0x00, 0x72,
        0xb6, 0x0d, 0x24, 0x00, 0x00, 0x00, 0x17, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9c, 0x63, 0xf8,
        0xcf, 0xc0, 0xf0, 0x1f, 0x08, 0x1b, 0x18, 0x80, 0xb4, 0x83, 0x90, 0x49, 0x98, 0x02, 0x00,
        0x38, 0xd1, 0x05, 0x79, 0xcc, 0xaa, 0x2a, 0x96, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4e,
        0x44, 0xae, 0x42, 0x60, 0x82,
    ];
    assert!(clipboard::write_rgba(owner.0, 2, 2, &rgba, Some(&png)));

    let clipboard = OpenClipboardGuard::open();
    let png_name: Vec<u16> = "PNG\0".encode_utf16().collect();
    // SAFETY: The format name is a terminated UTF-16 string.
    let png_format = unsafe { RegisterClipboardFormatW(png_name.as_ptr()) };
    assert_ne!(png_format, 0);
    // SAFETY: The clipboard is open and 0 requests the first available format.
    assert_eq!(unsafe { EnumClipboardFormats(0) }, png_format);
    assert_eq!(clipboard.read(png_format, png.len()), png);

    let dib = clipboard.read(CF_DIBV5, DIB_HEADER_SIZE + rgba.len());
    let dword = |offset| u32::from_le_bytes(dib[offset..offset + 4].try_into().unwrap());
    assert_eq!((dword(0), dword(4), dword(8)), (124, 2, 2));
    assert_eq!(dword(16), 3); // BI_BITFIELDS
    assert_eq!(dword(52), 0xff00_0000); // Alpha mask
    assert_eq!(
        &dib[DIB_HEADER_SIZE..],
        &[255, 0, 0, 64, 0x56, 0x34, 0x12, 32, 0, 0, 255, 255, 0, 255, 0, 128],
    ); // Bottom-up BGRA with straight alpha.
}
