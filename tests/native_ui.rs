//! Drives an actual desktop window and real operating-system input. Run only in
//! an isolated display or with the user's explicit permission (it moves the cursor).
#![cfg(feature = "ui-test-driver")]
use std::fs;
use std::process::{Child, Command, Stdio};
use std::time::{Duration, Instant};

#[path = "native_ui/input.rs"]
mod input;
#[path = "../crates/drill-core/src/test_directory.rs"]
mod test_directory;

use input::{Input, Key};

struct AppProcess(Child);
impl Drop for AppProcess {
    fn drop(&mut self) {
        if self.0.try_wait().ok().flatten().is_none() {
            let _ = self.0.kill();
            let _ = self.0.wait();
        }
    }
}
fn wait_for(path: &std::path::Path, predicate: impl Fn(&str) -> bool) -> String {
    let deadline = Instant::now() + Duration::from_secs(20);
    loop {
        if let Ok(status) = fs::read_to_string(path) {
            if predicate(&status) {
                return status;
            }
        }
        assert!(
            Instant::now() < deadline,
            "timed out waiting for UI state; last status: {:?}",
            fs::read_to_string(path)
        );
        std::thread::sleep(Duration::from_millis(50));
    }
}
#[test]
#[ignore = "moves the real mouse and types in a native window; run explicitly on a controlled desktop"]
fn native_typing_selection_and_escape() {
    let directory = test_directory::private_temp_dir();
    let root = directory.path();
    fs::write(root.join("drill_native_unique_test.txt"), "fixture").unwrap();
    fs::write(root.join("drill_native_unique_test-b.txt"), "fixture").unwrap();
    let status = root.join("ui-status.txt");
    let child = Command::new(env!("CARGO_BIN_EXE_drill"))
        .env("DRILL_UI_TEST_ROOT", root)
        .env("DRILL_UI_TEST_STATUS", &status)
        .stdout(Stdio::null())
        .stderr(Stdio::inherit())
        .spawn()
        .unwrap();
    let mut child = AppProcess(child);
    let initial = wait_for(&status, |s| s.contains("query=") && s.contains("x="));
    #[cfg(target_os = "linux")]
    let input = Input::for_process(child.0.id());
    #[cfg(not(target_os = "linux"))]
    let input = Input::at_window_origin(&initial);
    #[cfg(target_os = "linux")]
    let _ = initial;
    input.click(90, 25);
    input.text("drill_native_unique_test");
    wait_for(&status, |s| {
        s.contains("query=drill_native_unique_test") && s.contains("drill_native_unique_test.txt")
    });
    input.text("*.txt");
    wait_for(&status, |s| {
        s.contains("query=drill_native_unique_test*.txt\n")
            && s.contains("done=true")
            && s.contains("drill_native_unique_test-b.txt")
            && s.contains("drill_native_unique_test.txt")
    });
    input.click(30, 66);
    wait_for(&status, |s| {
        s.contains("sort=Some((Name, true))")
            && s.contains("drill_native_unique_test-b.txt|drill_native_unique_test.txt")
    });
    input.key(Key::DownArrow);
    wait_for(&status, |s| s.contains("selected=0"));
    input.key(Key::Escape);
    let deadline = Instant::now() + Duration::from_secs(10);
    loop {
        if let Some(exit) = child.0.try_wait().unwrap() {
            assert!(exit.success());
            break;
        }
        assert!(
            Instant::now() < deadline,
            "Escape did not close the native window"
        );
        std::thread::sleep(Duration::from_millis(50));
    }
}
