use std::path::Path;

use super::Icon;

pub(super) fn get_file_icon(path: &Path, size: u16) -> Option<Icon> {
    let pixels = drill_macos::file_icon(path, size)?;
    Some(Icon {
        width: u32::from(size),
        height: u32::from(size),
        pixels,
    })
}
