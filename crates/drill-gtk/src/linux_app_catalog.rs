//! The registered, visible desktop applications provided by GIO.

use std::ffi::{c_char, c_int, c_void, CStr, CString, OsStr};
use std::os::unix::ffi::OsStrExt;
use std::path::{Path, PathBuf};

pub struct DesktopApp {
    pub id: String,
    pub path: PathBuf,
    pub display_name: String,
    pub keywords: String,
    pub icon_names: Vec<String>,
}

pub enum LaunchError {
    Unavailable,
    Failed(String),
}

#[repr(C)]
struct RawDesktopApp {
    id: *const c_char,
    path: *const c_char,
    display_name: *const c_char,
    keywords: *const *const c_char,
    icon_names: *const *const c_char,
}

unsafe extern "C" {
    fn drill_visit_desktop_apps(
        context: *mut c_void,
        visit: unsafe extern "C" fn(*mut c_void, *const RawDesktopApp),
    );
    fn drill_launch_desktop_app(
        id: *const c_char,
        path: *const c_char,
        context: *mut c_void,
        report_error: unsafe extern "C" fn(*mut c_void, *const c_char),
    ) -> c_int;
}

/// Copy GIO's borrowed strings before the visitor returns control to C.
unsafe extern "C" fn collect_app(context: *mut c_void, app: *const RawDesktopApp) {
    // SAFETY: the C visitor supplies one live record with non-null, NUL-terminated scalars
    // and nullable, NULL-terminated arrays of NUL-terminated strings.
    let (id, path, display_name, keywords, icon_names) = unsafe {
        let app = &*app;
        (
            CStr::from_ptr(app.id),
            CStr::from_ptr(app.path),
            CStr::from_ptr(app.display_name),
            copy_strings(app.keywords),
            copy_strings(app.icon_names),
        )
    };
    let Ok(id) = id.to_str() else { return };
    // SAFETY: `load` passes a unique pointer to its vector for this synchronous visitor.
    let apps = unsafe { &mut *context.cast::<Vec<DesktopApp>>() };
    apps.push(DesktopApp {
        id: id.to_owned(),
        path: PathBuf::from(OsStr::from_bytes(path.to_bytes())),
        display_name: display_name.to_string_lossy().into_owned(),
        keywords: keywords.join(" "),
        icon_names,
    });
}

unsafe fn copy_strings(mut strings: *const *const c_char) -> Vec<String> {
    let mut result = Vec::new();
    if !strings.is_null() {
        loop {
            // SAFETY: the caller supplies a readable, NULL-terminated array of C strings.
            let value = unsafe { *strings };
            if value.is_null() {
                break;
            }
            // SAFETY: each non-null element points to a C string valid during the visitor call.
            result.push(
                unsafe { CStr::from_ptr(value) }
                    .to_string_lossy()
                    .into_owned(),
            );
            // SAFETY: the terminator follows the last non-null element in the array.
            strings = unsafe { strings.add(1) };
        }
    }
    result
}

pub fn load() -> Vec<DesktopApp> {
    let mut apps = Vec::new();
    // SAFETY: the visitor runs synchronously, with exclusive access to this live vector.
    unsafe { drill_visit_desktop_apps((&mut apps as *mut Vec<DesktopApp>).cast(), collect_app) };
    apps
}

unsafe extern "C" fn save_launch_error(context: *mut c_void, message: *const c_char) {
    // SAFETY: `launch` passes a unique pointer to its output. C passes a live GError message.
    unsafe {
        let output = &mut *context.cast::<Option<String>>();
        *output = Some(CStr::from_ptr(message).to_string_lossy().into_owned());
    }
}

/// Re-resolve the ID with GIO and launch only if its visible desktop file still matches `path`.
pub fn launch(id: &str, path: &Path) -> Result<(), LaunchError> {
    let id = CString::new(id).map_err(|_| LaunchError::Unavailable)?;
    let path = CString::new(path.as_os_str().as_bytes()).map_err(|_| LaunchError::Unavailable)?;
    let mut error = None;
    // SAFETY: both C strings and the callback output live until the native call returns.
    let status = unsafe {
        drill_launch_desktop_app(
            id.as_ptr(),
            path.as_ptr(),
            (&mut error as *mut Option<String>).cast(),
            save_launch_error,
        )
    };
    match status {
        0 => Ok(()),
        1 => Err(LaunchError::Unavailable),
        _ => Err(LaunchError::Failed(
            error.unwrap_or_else(|| "Could not launch application".into()),
        )),
    }
}
