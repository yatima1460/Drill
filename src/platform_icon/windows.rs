use std::path::Path;

use super::Icon;

pub(super) fn get_file_icon(path: &Path, size: u16) -> Option<Icon> {
    let icon = drill_windows::file_icon(path, size)?;
    Some(Icon {
        width: icon.width,
        height: icon.height,
        pixels: icon.pixels,
    })
}
