#![cfg_attr(target_os = "windows", windows_subsystem = "windows")]
#![deny(unsafe_code)]

// Cargo is an additional source-checkout launcher on macOS. The DMG contains
// the independently linked Swift executable, which runs without the checkout.
#[cfg(all(target_os = "macos", not(feature = "macos-egui")))]
fn main() -> std::io::Result<()> {
    use std::os::unix::process::CommandExt;
    use std::path::Path;
    use std::process::{exit, Command};

    let root = Path::new(env!("CARGO_MANIFEST_DIR"));
    let build = Command::new("python3")
        .arg(root.join("scripts/build-swift-ui.py"))
        .stdout(std::io::stderr())
        .status()?;
    if !build.success() {
        exit(build.code().unwrap_or(1));
    }

    let executable = root.join("target/swift-ui/Drill.app/Contents/MacOS/Drill");
    Err(Command::new(executable)
        .args(std::env::args_os().skip(1))
        .exec())
}

#[cfg(any(not(target_os = "macos"), feature = "macos-egui"))]
#[path = "mod.rs"]
mod egui_app;

#[cfg(any(not(target_os = "macos"), feature = "macos-egui"))]
fn main() -> eframe::Result {
    egui_app::run()
}

#[cfg(all(test, any(not(target_os = "macos"), feature = "macos-egui")))]
#[path = "../crates/drill-core/src/test_directory.rs"]
mod test_directory;
