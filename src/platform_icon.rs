use std::path::Path;

#[cfg(target_os = "macos")]
mod macos;
#[cfg(windows)]
mod windows;

#[cfg(target_os = "linux")]
pub(crate) use drill_gtk::{mime_type_icon, open_with, themed_icon, Icon};

#[cfg(target_os = "linux")]
use drill_gtk as native;
#[cfg(target_os = "macos")]
use macos as native;
#[cfg(windows)]
use windows as native;

#[cfg(not(target_os = "linux"))]
pub(crate) struct Icon {
    pub(crate) width: u32,
    pub(crate) height: u32,
    pub(crate) pixels: Vec<u8>,
}

#[cfg(any(target_os = "linux", target_os = "macos", windows))]
pub(crate) fn get_file_icon(path: &Path, size: u16) -> Option<Icon> {
    // Keep allocation bounded even if a caller requests an unexpectedly large icon.
    if !(1..=256).contains(&size) {
        return None;
    }
    native::get_file_icon(path, size)
}

#[cfg(not(any(target_os = "linux", target_os = "macos", windows)))]
pub(crate) fn get_file_icon(_: &Path, _: u16) -> Option<Icon> {
    None
}
