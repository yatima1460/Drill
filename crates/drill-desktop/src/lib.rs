//! Shared search and table model for the Win32 and GTK desktop frontends.
#![cfg(any(windows, target_os = "linux", test))]

mod icons;
#[cfg(target_os = "linux")]
mod linux_apps;
mod model;
mod result_date;
mod result_order;
mod rows;
mod search;
#[cfg(test)]
#[path = "../../drill-core/src/test_directory.rs"]
mod test_directory;
#[cfg(test)]
mod tests;

use icons::IconResult;
use model::Model;
use rows::Column;
use std::ffi::{c_char, c_int, c_uint, CStr};
use std::time::Instant;

#[cfg(windows)]
type DrillPathChar = u16;
#[cfg(unix)]
type DrillPathChar = c_char;

#[repr(C)]
struct DrillState {
    revision: u64,
    icon_revision: u64,
    count: usize,
    selected_index: i64,
    status: *const c_char,
    can_stop: bool,
    can_continue: bool,
}

#[repr(C)]
struct DrillRow {
    cells: [*const c_char; 4],
    path: *const DrillPathChar,
    directory: bool,
    registered_app: bool,
    desktop_id: *const c_char,
}

#[cfg(any(windows, target_os = "linux"))]
pub fn run(root: Option<std::path::PathBuf>) -> i32 {
    // Select the platform crate's native archive even when the only reference
    // to its UI is the C symbol below (not a Rust function or type).
    #[cfg(target_os = "linux")]
    use drill_gtk as _;
    #[cfg(windows)]
    use drill_windows as _;
    unsafe extern "C" {
        fn drill_native_run(model: *mut std::ffi::c_void) -> c_int;
    }
    let mut model = Model::new(root);
    // SAFETY: the UI borrows the model for this synchronous event loop. All its
    // callbacks are serialized on the same thread and finish before returning.
    unsafe { drill_native_run(std::ptr::from_mut(&mut model).cast()) }
}

// The adapters supply the live model borrowed in run(). Every returned string
// is owned by that model; see include/DrillDesktop.h for the borrowing contract.
#[no_mangle]
unsafe extern "C" fn drill_query(model: &mut Model, query: *const c_char, apps: bool) {
    if query.is_null() {
        return;
    }
    // SAFETY: the native search control supplied NUL-terminated UTF-8.
    let query = unsafe { CStr::from_ptr(query) };
    model.query(&query.to_string_lossy(), apps, Instant::now());
}

#[no_mangle]
extern "C" fn drill_tick(model: &mut Model) -> DrillState {
    model.tick(Instant::now());
    DrillState {
        revision: model.revision,
        icon_revision: model.icon_revision,
        count: model.rows.len(),
        selected_index: model.rows.selected.map_or(-1, |index| index as i64),
        status: model.status.as_ptr(),
        can_stop: model.can_stop(),
        can_continue: model.can_continue(),
    }
}

#[no_mangle]
extern "C" fn drill_stop(model: &mut Model) {
    model.stop();
}

#[no_mangle]
extern "C" fn drill_continue(model: &mut Model) {
    model.resume();
}

#[no_mangle]
extern "C" fn drill_sort(model: &mut Model, column: c_uint) {
    let column = match column {
        0 => Column::Name,
        1 => Column::Path,
        2 => Column::Size,
        3 => Column::Date,
        _ => return,
    };
    model.rows.sort(column);
    model.revision += 1;
}

#[no_mangle]
extern "C" fn drill_select(model: &mut Model, id: u64) {
    if model.rows.select(id) {
        model.revision += 1;
    }
}

#[no_mangle]
extern "C" fn drill_row_id(model: &Model, index: usize) -> u64 {
    model.rows.id(index).unwrap_or(0)
}

#[no_mangle]
unsafe extern "C" fn drill_row(model: &Model, id: u64, out: *mut DrillRow) -> bool {
    let Some(row) = model.rows.get(id) else {
        return false;
    };
    if out.is_null() {
        return false;
    }
    // SAFETY: out is the caller's writable DrillRow.
    unsafe { out.write(row.native()) };
    true
}

#[no_mangle]
unsafe extern "C" fn drill_embedded_icon(
    model: &mut Model,
    id: u64,
    exe: bool,
    appimage: bool,
    rgba: *mut u8,
) -> c_int {
    let Some(row) = model.rows.get(id) else {
        return -1;
    };
    if row.hit.entry.is_dir || rgba.is_null() {
        return -1;
    }
    match model.icons.request(&row.hit.entry.path, exe, appimage) {
        IconResult::Ready(bytes) if bytes.len() == drill_icons::RGBA_BYTES => {
            // SAFETY: the caller provides the fixed-size output buffer defined
            // by the header; the source is a disjoint, verified RGBA image.
            unsafe { std::ptr::copy_nonoverlapping(bytes.as_ptr(), rgba, drill_icons::RGBA_BYTES) };
            1
        }
        IconResult::Pending => 0,
        _ => -1,
    }
}
