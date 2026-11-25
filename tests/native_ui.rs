//! Drives an actual desktop window and real operating-system input. Run only in
//! an isolated display or with the user's explicit permission (it moves the cursor).
#![cfg(feature = "ui-test-driver")]
#[cfg(not(target_os = "linux"))]
use enigo::Coordinate;
use enigo::{Button, Direction, Enigo, Key, Keyboard, Mouse, Settings};
use std::fs;
use std::process::{Child, Command, Stdio};
use std::time::{Duration, Instant};

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
    let root = std::env::temp_dir().join(format!("drill-native-ui-{}", std::process::id()));
    fs::create_dir_all(&root).unwrap();
    fs::write(root.join("drill_native_unique_test.txt"), "fixture").unwrap();
    fs::write(root.join("drill_native_unique_test-b.txt"), "fixture").unwrap();
    let status = root.join("ui-status.txt");
    let child = Command::new(env!("CARGO_BIN_EXE_drill"))
        .env("DRILL_UI_TEST_ROOT", &root)
        .env("DRILL_UI_TEST_STATUS", &status)
        .stdout(Stdio::null())
        .stderr(Stdio::inherit())
        .spawn()
        .unwrap();
    let mut child = AppProcess(child);
    let initial = wait_for(&status, |s| s.contains("query=") && s.contains("x="));
    #[cfg(target_os = "linux")]
    let window_id = {
        let pid = child.0.id().to_string();
        let found = Command::new("timeout")
            .args([
                "15s",
                "xdotool",
                "search",
                "--sync",
                "--onlyvisible",
                "--pid",
                &pid,
            ])
            .output()
            .expect("xdotool is required for native UI tests on X11");
        assert!(
            found.status.success(),
            "could not find the test window within 15 seconds: {}",
            String::from_utf8_lossy(&found.stderr)
        );
        let ids = String::from_utf8(found.stdout).unwrap();
        let id = ids
            .lines()
            .next()
            .expect("missing X11 window id")
            .to_string();
        let focused = Command::new("timeout")
            .args(["10s", "xdotool", "windowactivate", "--sync", &id])
            .status()
            .unwrap();
        assert!(
            focused.success(),
            "could not focus the test window within 10 seconds"
        );
        id
    };
    #[cfg(not(target_os = "linux"))]
    let origin = {
        let field = |name: &str| {
            initial
                .lines()
                .find_map(|line| line.strip_prefix(name))
                .unwrap()
                .parse::<f32>()
                .unwrap() as i32
        };
        (field("x="), field("y="))
    };
    #[cfg(target_os = "linux")]
    let _ = initial;
    let mut input = Enigo::new(&Settings::default()).expect("Cannot create OS input driver; on macOS enable Accessibility permission for the app running this test");
    #[cfg(target_os = "linux")]
    assert!(Command::new("xdotool")
        .args(["mousemove", "--window", &window_id, "90", "47"])
        .status()
        .unwrap()
        .success());
    #[cfg(not(target_os = "linux"))]
    input
        .move_mouse(origin.0 + 90, origin.1 + 25, Coordinate::Abs)
        .unwrap();
    input.button(Button::Left, Direction::Click).unwrap();
    input
        .text("drill_native_unique_test")
        .expect("typing requires OS input permission");
    wait_for(&status, |s| {
        s.contains("query=drill_native_unique_test") && s.contains("drill_native_unique_test.txt")
    });
    #[cfg(target_os = "linux")]
    assert!(Command::new("xdotool")
        .args(["mousemove", "--window", &window_id, "30", "88"])
        .status()
        .unwrap()
        .success());
    #[cfg(not(target_os = "linux"))]
    input
        .move_mouse(origin.0 + 30, origin.1 + 66, Coordinate::Abs)
        .unwrap();
    input.button(Button::Left, Direction::Click).unwrap();
    wait_for(&status, |s| {
        s.contains("sort=Some((Name, true))")
            && s.contains("drill_native_unique_test-b.txt|drill_native_unique_test.txt")
    });
    input.key(Key::DownArrow, Direction::Click).unwrap();
    wait_for(&status, |s| s.contains("selected=0"));
    input.key(Key::Escape, Direction::Click).unwrap();
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
    fs::remove_dir_all(root).unwrap();
}
