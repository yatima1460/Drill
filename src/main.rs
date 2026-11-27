#![cfg_attr(target_os = "windows", windows_subsystem = "windows")]
#![deny(unsafe_code)]

// Cargo is an additional source-checkout launcher on macOS. The DMG contains
// the independently linked Swift executable, which runs without the checkout.
#[cfg(target_os = "macos")]
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

#[cfg(any(target_os = "linux", windows))]
fn main() -> std::process::ExitCode {
    use std::process::ExitCode;

    let mut args = std::env::args_os().skip(1);
    let mut root = None;
    while let Some(arg) = args.next() {
        if arg == "--version" {
            println!("Drill {}", env!("CARGO_PKG_VERSION"));
            return ExitCode::SUCCESS;
        }
        if arg == "--root" {
            let Some(path) = args.next().filter(|p| !p.is_empty()) else {
                eprintln!("Expected a directory after --root");
                return ExitCode::from(2);
            };
            match std::path::absolute(&path) {
                Ok(path) => root = Some(path),
                Err(error) => {
                    eprintln!("Could not resolve --root {path:?}: {error}");
                    return ExitCode::from(2);
                }
            }
        }
    }
    if drill_desktop::run(root) == 0 {
        ExitCode::SUCCESS
    } else {
        ExitCode::FAILURE
    }
}
