use std::ffi::{c_char, CStr, CString, OsStr};
use std::os::unix::ffi::OsStrExt;
use std::path::{Path, PathBuf};
use std::ptr;

const PATH_MAX: usize = 1024; // Darwin's maximum filesystem path buffer, including the terminator.

unsafe extern "C" {
    fn drill_macos_pick_folder(
        starting_folder: *const c_char,
        selected_folder: *mut c_char,
        selected_folder_capacity: usize,
    ) -> bool;
}

pub fn pick_folder(starting_folder: Option<&Path>) -> Option<PathBuf> {
    let starting_folder = starting_folder
        .filter(|path| !path.as_os_str().is_empty())
        .and_then(|path| CString::new(path.as_os_str().as_bytes()).ok());
    let mut selected_folder = [0u8; PATH_MAX];
    // SAFETY: the starting path is null or a live C string, and the output buffer is writable
    // for the call. The native picker refuses to present AppKit UI outside the main thread.
    let picked = unsafe {
        drill_macos_pick_folder(
            starting_folder
                .as_ref()
                .map_or(ptr::null(), |path| path.as_ptr()),
            selected_folder.as_mut_ptr().cast(),
            selected_folder.len(),
        )
    };
    if !picked {
        return None;
    }

    let path = CStr::from_bytes_until_nul(&selected_folder).ok()?;
    Some(PathBuf::from(OsStr::from_bytes(path.to_bytes())))
}
