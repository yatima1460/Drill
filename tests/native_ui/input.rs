pub enum Key {
    DownArrow,
    Escape,
}

#[cfg(target_os = "linux")]
pub use x11::Input;
#[cfg(target_os = "linux")]
mod x11 {
    use super::Key;
    use std::process::Command;

    pub struct Input(String);

    fn xdotool(seconds: &str, args: &[&str]) -> String {
        let output = Command::new("timeout")
            .args([seconds, "xdotool"])
            .args(args)
            .output()
            .expect("timeout and xdotool are required for native UI tests on X11");
        assert!(
            output.status.success(),
            "xdotool {args:?} exited with {}: {}",
            output.status,
            String::from_utf8_lossy(&output.stderr)
        );
        String::from_utf8(output.stdout).unwrap()
    }

    impl Input {
        pub fn for_process(pid: u32) -> Self {
            let windows = xdotool(
                "15s",
                &[
                    "search",
                    "--sync",
                    "--onlyvisible",
                    "--pid",
                    &pid.to_string(),
                ],
            );
            let window = windows.lines().next().expect("missing X11 window id");
            xdotool("10s", &["windowactivate", "--sync", window]);
            Self(window.to_owned())
        }

        pub fn click(&self, x: i32, y: i32) {
            // The Linux content area includes Drill's menu bar.
            xdotool(
                "10s",
                &[
                    "mousemove",
                    "--window",
                    &self.0,
                    &x.to_string(),
                    &(y + 22).to_string(),
                    "click",
                    "1",
                ],
            );
        }

        pub fn text(&self, text: &str) {
            xdotool("10s", &["type", "--clearmodifiers", "--", text]);
        }

        pub fn key(&self, key: Key) {
            let name = match key {
                Key::DownArrow => "Down",
                Key::Escape => "Escape",
            };
            xdotool("10s", &["key", "--clearmodifiers", name]);
        }
    }
}

#[cfg(not(target_os = "linux"))]
fn window_origin(status: &str) -> (i32, i32) {
    let field = |name: &str| {
        status
            .lines()
            .find_map(|line| line.strip_prefix(name))
            .unwrap()
            .parse::<f32>()
            .unwrap() as i32
    };
    (field("x="), field("y="))
}

#[cfg(target_os = "macos")]
pub use macos::Input;
#[cfg(target_os = "macos")]
mod macos {
    use super::{window_origin, Key};
    use std::ffi::{c_ulong, c_void};
    use std::ptr::NonNull;

    const PRIVATE_SOURCE: i32 = -1;
    const HID_EVENT_TAP: u32 = 0;
    const LEFT_MOUSE_DOWN: u32 = 1;
    const LEFT_MOUSE_UP: u32 = 2;
    const MOUSE_MOVED: u32 = 5;
    const LEFT_MOUSE_BUTTON: u32 = 0;
    const MOUSE_CLICK_STATE: u32 = 1;

    #[repr(C)]
    #[derive(Clone, Copy)]
    struct Point {
        x: f64,
        y: f64,
    }

    #[link(name = "CoreGraphics", kind = "framework")]
    unsafe extern "C" {
        fn CGRequestPostEventAccess() -> bool;
        fn CGEventSourceCreate(state: i32) -> *mut c_void;
        fn CGEventCreateMouseEvent(
            source: *mut c_void,
            kind: u32,
            position: Point,
            button: u32,
        ) -> *mut c_void;
        fn CGEventCreateKeyboardEvent(source: *mut c_void, code: u16, down: bool) -> *mut c_void;
        fn CGEventSetIntegerValueField(event: *mut c_void, field: u32, value: i64);
        fn CGEventSetFlags(event: *mut c_void, flags: u64);
        fn CGEventKeyboardSetUnicodeString(event: *mut c_void, length: c_ulong, text: *const u16);
        fn CGEventPost(tap: u32, event: *mut c_void);
    }

    #[link(name = "CoreFoundation", kind = "framework")]
    unsafe extern "C" {
        fn CFRelease(object: *const c_void);
    }

    // Owns the retained reference returned by a Core Graphics Create function.
    struct OwnedCf(NonNull<c_void>);

    impl Drop for OwnedCf {
        fn drop(&mut self) {
            // SAFETY: The matching Create function transferred ownership of this reference.
            unsafe { CFRelease(self.0.as_ptr()) };
        }
    }

    pub struct Input {
        origin: (i32, i32),
        source: OwnedCf,
    }

    impl Input {
        pub fn at_window_origin(status: &str) -> Self {
            let origin = window_origin(status);
            // SAFETY: This call takes no arguments and requests event posting permission.
            assert!(
                unsafe { CGRequestPostEventAccess() },
                "Enable Accessibility permission for the app running this test"
            );
            // SAFETY: PRIVATE_SOURCE is the SDK's private event source state.
            let source = unsafe { CGEventSourceCreate(PRIVATE_SOURCE) };
            Self {
                origin,
                source: OwnedCf(
                    NonNull::new(source).expect("could not create Quartz event source"),
                ),
            }
        }

        pub fn click(&self, x: i32, y: i32) {
            let position = Point {
                x: f64::from(self.origin.0 + x),
                y: f64::from(self.origin.1 + y),
            };
            for kind in [MOUSE_MOVED, LEFT_MOUSE_DOWN, LEFT_MOUSE_UP] {
                // SAFETY: The source is live and the event kind and button are SDK constants.
                let event = unsafe {
                    CGEventCreateMouseEvent(
                        self.source.0.as_ptr(),
                        kind,
                        position,
                        LEFT_MOUSE_BUTTON,
                    )
                };
                let event =
                    OwnedCf(NonNull::new(event).expect("could not create Quartz mouse event"));
                // SAFETY: The event remains live through both calls.
                unsafe {
                    if kind != MOUSE_MOVED {
                        CGEventSetIntegerValueField(event.0.as_ptr(), MOUSE_CLICK_STATE, 1);
                    }
                    CGEventPost(HID_EVENT_TAP, event.0.as_ptr());
                }
            }
        }

        fn keyboard_event(&self, code: u16, down: bool) -> OwnedCf {
            // SAFETY: The source is live and the callers use valid Quartz virtual key codes.
            let event = unsafe { CGEventCreateKeyboardEvent(self.source.0.as_ptr(), code, down) };
            OwnedCf(NonNull::new(event).expect("could not create Quartz key event"))
        }

        pub fn text(&self, text: &str) {
            for character in text.chars() {
                let event = self.keyboard_event(0, true);
                let mut buffer = [0; 2];
                let utf16 = character.encode_utf16(&mut buffer);
                // SAFETY: The event is live and the slice contains length UTF-16 code units.
                unsafe {
                    CGEventSetFlags(event.0.as_ptr(), 0);
                    CGEventKeyboardSetUnicodeString(
                        event.0.as_ptr(),
                        utf16.len() as c_ulong,
                        utf16.as_ptr(),
                    );
                    CGEventPost(HID_EVENT_TAP, event.0.as_ptr());
                }
            }
        }

        pub fn key(&self, key: Key) {
            // Carbon virtual key codes from HIToolbox/Events.h.
            let code = match key {
                Key::DownArrow => 0x7d,
                Key::Escape => 0x35,
            };
            for pressed in [true, false] {
                let event = self.keyboard_event(code, pressed);
                // SAFETY: The event is live until the call returns.
                unsafe { CGEventPost(HID_EVENT_TAP, event.0.as_ptr()) };
            }
        }
    }
}

#[cfg(target_os = "windows")]
pub use windows::Input;
#[cfg(target_os = "windows")]
mod windows {
    use super::{window_origin, Key};
    use std::io;
    use std::mem::size_of;
    const INPUT_MOUSE: u32 = 0;
    const INPUT_KEYBOARD: u32 = 1;
    const KEYEVENTF_EXTENDEDKEY: u32 = 0x0001;
    const KEYEVENTF_KEYUP: u32 = 0x0002;
    const KEYEVENTF_UNICODE: u32 = 0x0004;
    const MOUSEEVENTF_LEFTDOWN: u32 = 0x0002;
    const MOUSEEVENTF_LEFTUP: u32 = 0x0004;
    const VK_DOWN: u16 = 0x28;
    const VK_ESCAPE: u16 = 0x1b;

    // winuser.h's INPUT, using the mouse and keyboard members of its union.
    #[repr(C)]
    struct WinInput {
        kind: u32,
        event: InputEvent,
    }

    #[repr(C)]
    union InputEvent {
        mouse: MouseInput,
        keyboard: KeyboardInput,
    }

    #[repr(C)]
    #[derive(Clone, Copy, Default)]
    struct MouseInput {
        dx: i32,
        dy: i32,
        data: u32,
        flags: u32,
        time: u32,
        extra_info: usize,
    }

    #[repr(C)]
    #[derive(Clone, Copy, Default)]
    struct KeyboardInput {
        virtual_key: u16,
        scan: u16,
        flags: u32,
        time: u32,
        extra_info: usize,
    }

    #[link(name = "user32")]
    unsafe extern "system" {
        fn SendInput(count: u32, inputs: *const WinInput, size: i32) -> u32;
        fn SetCursorPos(x: i32, y: i32) -> i32;
    }

    pub struct Input((i32, i32));

    fn send(events: &[WinInput]) {
        let count = events.len() as u32;
        // SAFETY: The slice contains count initialized INPUTs of the specified size.
        let sent = unsafe { SendInput(count, events.as_ptr(), size_of::<WinInput>() as i32) };
        assert_eq!(
            sent,
            count,
            "SendInput failed: {}",
            io::Error::last_os_error()
        );
    }

    fn keystroke(virtual_key: u16, scan: u16, flags: u32) -> [WinInput; 2] {
        [flags, flags | KEYEVENTF_KEYUP].map(|flags| WinInput {
            kind: INPUT_KEYBOARD,
            event: InputEvent {
                keyboard: KeyboardInput {
                    virtual_key,
                    scan,
                    flags,
                    ..KeyboardInput::default()
                },
            },
        })
    }

    impl Input {
        pub fn at_window_origin(status: &str) -> Self {
            Self(window_origin(status))
        }

        pub fn click(&self, x: i32, y: i32) {
            let (left, top) = self.0;
            // SAFETY: SetCursorPos only receives the intended screen coordinates.
            let moved = unsafe { SetCursorPos(left + x, top + y) };
            assert_ne!(
                moved,
                0,
                "SetCursorPos failed: {}",
                io::Error::last_os_error()
            );
            send(
                &[MOUSEEVENTF_LEFTDOWN, MOUSEEVENTF_LEFTUP].map(|flags| WinInput {
                    kind: INPUT_MOUSE,
                    event: InputEvent {
                        mouse: MouseInput {
                            flags,
                            ..MouseInput::default()
                        },
                    },
                }),
            );
        }

        pub fn text(&self, text: &str) {
            let events: Vec<_> = text
                .encode_utf16()
                .flat_map(|unit| keystroke(0, unit, KEYEVENTF_UNICODE))
                .collect();
            send(&events);
        }

        pub fn key(&self, key: Key) {
            let (code, flags) = match key {
                Key::DownArrow => (VK_DOWN, KEYEVENTF_EXTENDEDKEY),
                Key::Escape => (VK_ESCAPE, 0),
            };
            send(&keystroke(code, 0, flags));
        }
    }
}
