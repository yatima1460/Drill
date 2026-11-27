#![cfg(windows)]
#![deny(unsafe_code)]
//! Windows filesystem and Shell adapters for Drill.

#[cfg(feature = "clipboard")]
#[allow(unsafe_code)]
pub mod clipboard;

#[cfg(feature = "menu")]
#[allow(unsafe_code)]
pub mod menu;

#[cfg(feature = "shell-icons")]
#[allow(unsafe_code)]
mod file_icon;
#[cfg(feature = "shell-icons")]
pub use file_icon::{file_icon, FileIcon};

use std::ffi::c_void;
use std::mem::MaybeUninit;
use std::os::windows::ffi::OsStrExt;
use std::path::Path;

// WIN32_FIND_DATAW in the Windows SDK's minwinbase.h. Each FILETIME is two DWORDs.
// The obsolete _MAC fields in legacy headers are absent from the Windows ABI.
#[repr(C)]
struct Win32FindData {
    _file_attributes: u32,
    _creation_time: [u32; 2],
    _last_access_time: [u32; 2],
    _last_write_time: [u32; 2],
    _file_size_high: u32,
    _file_size_low: u32,
    _reserved0: u32,
    _reserved1: u32,
    file_name: [u16; 260],
    _alternate_file_name: [u16; 14],
}

const _: () = {
    assert!(std::mem::size_of::<Win32FindData>() == 592);
    assert!(std::mem::align_of::<Win32FindData>() == 4);
    assert!(std::mem::offset_of!(Win32FindData, file_name) == 44);
    assert!(std::mem::offset_of!(Win32FindData, _alternate_file_name) == 564);
};

const INVALID_HANDLE_VALUE: *mut c_void = std::ptr::without_provenance_mut(usize::MAX);

#[allow(unsafe_code)]
#[link(name = "kernel32")]
unsafe extern "system" {
    fn FindFirstFileW(path: *const u16, data: *mut Win32FindData) -> *mut c_void;
    fn FindClose(handle: *mut c_void) -> i32;
}

/// Look up a literal path and return the filename stored in its directory entry.
#[allow(unsafe_code)]
pub fn find_filename(path: &Path) -> Option<String> {
    let mut wide_path: Vec<_> = path.as_os_str().encode_wide().collect();
    if wide_path.is_empty() || wide_path.contains(&0) {
        return None;
    }
    wide_path.push(0);
    let mut data = MaybeUninit::<Win32FindData>::zeroed();
    // SAFETY: the path is NUL-terminated and the output points to a writable find-data structure.
    let handle = unsafe { FindFirstFileW(wide_path.as_ptr(), data.as_mut_ptr()) };
    if handle == INVALID_HANDLE_VALUE {
        return None;
    }
    // SAFETY: this handle came from a successful FindFirstFileW and is closed exactly once.
    unsafe { FindClose(handle) };
    // SAFETY: the structure contains only integers and was zeroed before Windows filled it.
    let data = unsafe { data.assume_init() };
    let name_end = data.file_name.iter().position(|&unit| unit == 0)?;
    String::from_utf16(&data.file_name[..name_end]).ok()
}
