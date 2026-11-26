pub(super) use drill_macos::menu::{Command as NativeCommand, Menu};

pub(super) fn install(
    _: &eframe::CreationContext<'_>,
    callback: impl Fn(NativeCommand) + 'static,
) -> Result<Menu, String> {
    Menu::install(callback).ok_or_else(|| "The macOS application menu is unavailable".into())
}
