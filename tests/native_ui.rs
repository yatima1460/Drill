//! Run on an isolated X11 display with a window manager and session D-Bus.
#![cfg(target_os = "linux")]

#[test]
#[ignore = "moves the mouse and types in the native window"]
fn gtk_search_and_file_actions() {
    let status = std::process::Command::new("python3")
        .arg(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/tests/native_ui/linux.py"
        ))
        .args(["test", env!("CARGO_BIN_EXE_drill")])
        .status()
        .expect("start the GTK accessibility and input test");
    assert!(
        status.success(),
        "GTK interaction test exited with {status}"
    );
}
