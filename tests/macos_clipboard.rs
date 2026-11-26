#![cfg(target_os = "macos")]

#[test]
fn macos_paste_shortcuts_follow_egui_precedence() {
    eframe::clipboard_test_cases::macos_paste_shortcuts_follow_egui_precedence();
}

#[test]
fn native_paste_replaces_the_framework_fallback_once() {
    eframe::clipboard_test_cases::native_paste_replaces_the_framework_fallback_once();
}
