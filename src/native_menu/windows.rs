use raw_window_handle::{HasWindowHandle, RawWindowHandle};

pub(super) use drill_windows::menu::{Command as NativeCommand, Menu};

#[allow(unsafe_code)]
pub(super) fn install(
    creation: &eframe::CreationContext<'_>,
    callback: impl Fn(NativeCommand) + 'static,
) -> Result<Menu, String> {
    let handle = creation.window_handle().map_err(|e| e.to_string())?;
    let RawWindowHandle::Win32(handle) = handle.as_raw() else {
        return Err("Expected a Windows window".into());
    };
    // SAFETY: eframe owns this live top-level HWND on its creation thread.
    unsafe { Menu::install(handle.hwnd, callback) }
        .ok_or_else(|| "Could not install the Windows menu bar".into())
}
