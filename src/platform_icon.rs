use std::path::Path;

#[cfg(target_os = "macos")]
mod macos;

#[cfg(target_os = "macos")]
pub(crate) struct Icon {
    pub(crate) width: u32,
    pub(crate) height: u32,
    pub(crate) pixels: Vec<u8>,
}

#[cfg(not(target_os = "macos"))]
pub(crate) use file_icon_provider::Icon;

pub(crate) fn get_file_icon(path: &Path, size: u16) -> Option<Icon> {
    if !(1..=256).contains(&size) {
        return None;
    }
    #[cfg(target_os = "macos")]
    {
        macos::get_file_icon(path, size)
    }
    #[cfg(not(target_os = "macos"))]
    {
        file_icon_provider::get_file_icon(path, size).ok()
    }
}
