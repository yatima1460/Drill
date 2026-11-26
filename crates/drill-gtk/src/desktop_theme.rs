//! Watches the desktop appearance portal on a private GIO context.
use std::{
    ffi::{c_int, c_void},
    ptr::NonNull,
    sync::Arc,
    thread,
};

unsafe extern "C" {
    fn drill_desktop_theme_new_stop() -> *mut c_void;
    fn drill_desktop_theme_stop(stop: *mut c_void);
    fn drill_desktop_theme_free_stop(stop: *mut c_void);
    fn drill_desktop_theme_observe(
        stop: *mut c_void,
        publish: unsafe extern "C" fn(c_int, *mut c_void),
        data: *mut c_void,
    );
}

struct Stop(NonNull<c_void>);

// SAFETY: The pointer owns a GCancellable, whose cancellation and reference
// counting operations are thread-safe. The worker holds a separate Arc.
unsafe impl Send for Stop {}
// SAFETY: Shared access performs only GCancellable's thread-safe cancel operation.
unsafe impl Sync for Stop {}

impl Drop for Stop {
    fn drop(&mut self) {
        // SAFETY: The last Arc owns the reference created by new_stop.
        unsafe { drill_desktop_theme_free_stop(self.0.as_ptr()) };
    }
}

pub struct Observer {
    stop: Arc<Stop>,
}

impl Observer {
    /// Publishes whether the current preference is dark, or None when the
    /// portal has no usable setting. The callback runs on the worker.
    pub fn start<F: Fn(Option<bool>) + Send + 'static>(publish: F) -> Self {
        // SAFETY: GIO constructs a new GCancellable with an owned reference.
        let native = unsafe { drill_desktop_theme_new_stop() };
        let stop = Arc::new(Stop(NonNull::new(native).expect("create theme canceller")));
        let worker_stop = Arc::clone(&stop);
        let _ = thread::Builder::new()
            .name("drill-desktop-theme".into())
            .spawn(move || {
                unsafe extern "C" fn update<F: Fn(Option<bool>)>(theme: c_int, data: *mut c_void) {
                    // SAFETY: observe calls back on this worker while the borrowed F is alive.
                    let publish = unsafe { &*data.cast::<F>() };
                    publish(match theme {
                        1 => Some(false),
                        2 => Some(true),
                        _ => None,
                    });
                }

                // SAFETY: Both captures outlive the call, which drains callbacks before returning.
                unsafe {
                    drill_desktop_theme_observe(
                        worker_stop.0.as_ptr(),
                        update::<F>,
                        (&raw const publish).cast_mut().cast(),
                    );
                }
            });
        Self { stop }
    }
}

impl Drop for Observer {
    fn drop(&mut self) {
        // SAFETY: The Arc keeps the GCancellable live, and cancellation is thread-safe.
        unsafe { drill_desktop_theme_stop(self.stop.0.as_ptr()) };
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::{
        ffi::{c_char, CStr},
        process::Command,
        sync::mpsc,
        time::{Duration, Instant},
    };

    unsafe extern "C" {
        fn drill_theme_fixture_new() -> *mut c_void;
        fn drill_theme_fixture_set_owner(fixture: *mut c_void, acquire: c_int);
        fn drill_theme_fixture_emit(
            fixture: *mut c_void,
            namespace: *const c_char,
            key: *const c_char,
            value: c_int,
        );
        fn drill_theme_fixture_hold_read(fixture: *mut c_void);
        fn drill_theme_fixture_dispatch(fixture: *mut c_void) -> c_int;
        fn drill_theme_fixture_reply(fixture: *mut c_void);
        fn drill_theme_fixture_free(fixture: *mut c_void);
    }

    struct Fixture(*mut c_void);

    impl Fixture {
        fn new() -> Self {
            // SAFETY: This is the isolated session-bus subprocess.
            Self(unsafe { drill_theme_fixture_new() })
        }

        fn set_owner(&self, acquire: bool) {
            // SAFETY: This fixture owns a live mock on the current thread.
            unsafe { drill_theme_fixture_set_owner(self.0, acquire.into()) };
        }

        fn emit(&self, namespace: &CStr, key: &CStr, value: c_int) {
            // SAFETY: The fixture and NUL-terminated arguments outlive this call.
            unsafe { drill_theme_fixture_emit(self.0, namespace.as_ptr(), key.as_ptr(), value) };
        }

        fn hold_read(&self) {
            // SAFETY: This fixture owns the mock on the current thread.
            unsafe { drill_theme_fixture_hold_read(self.0) };
        }

        fn reply(&self) {
            // SAFETY: This fixture owns the mock and has received a ReadAll request.
            unsafe { drill_theme_fixture_reply(self.0) };
        }

        fn wait<T>(&self, what: &str, mut ready: impl FnMut(bool) -> Option<T>) -> T {
            let deadline = Instant::now() + Duration::from_secs(5);
            loop {
                // SAFETY: Dispatch on the fixture's owning thread.
                let pending_read = unsafe { drill_theme_fixture_dispatch(self.0) } != 0;
                if let Some(value) = ready(pending_read) {
                    return value;
                }
                assert!(Instant::now() < deadline, "timed out waiting for {what}");
                thread::sleep(Duration::from_millis(10));
            }
        }
        fn next(&self, updates: &mpsc::Receiver<Option<bool>>) -> Option<bool> {
            self.wait("desktop theme update", |_| updates.try_recv().ok())
        }

        fn wait_for_read(&self) {
            self.wait("ReadAll request", |pending| pending.then_some(()));
        }
    }

    impl Drop for Fixture {
        fn drop(&mut self) {
            // SAFETY: The matching new call allocated this fixture on the same thread.
            unsafe { drill_theme_fixture_free(self.0) };
        }
    }

    #[test]
    fn native_portal_tracks_initial_theme_live_changes_and_owner_loss() {
        const CHILD: &str = "DRILL_TEST_ISOLATED_THEME_BUS";
        const TEST: &str = "native_portal_tracks_initial_theme_live_changes_and_owner_loss";
        if std::env::var_os(CHILD).is_none() {
            let status = Command::new("dbus-run-session")
                .arg("--")
                .arg(std::env::current_exe().unwrap())
                .args([TEST, "--nocapture"])
                .env(CHILD, "1")
                .status()
                .expect("native desktop theme test requires dbus-run-session");
            assert!(status.success());
            return;
        }

        let bus = Fixture::new();
        bus.set_owner(true);
        let (publish, updates) = mpsc::channel();
        let observer = Observer::start(move |theme| {
            let _ = publish.send(theme);
        });

        let namespace = c"org.freedesktop.appearance";
        let key = c"color-scheme";
        assert_eq!(bus.next(&updates), Some(true));
        for (raw, expected) in [
            (0, Some(false)),
            (1, Some(true)),
            (2, Some(false)),
            (33, Some(false)),
            (-1, None),
        ] {
            bus.emit(namespace, key, raw);
            assert_eq!(bus.next(&updates), expected);
        }
        bus.emit(namespace, c"contrast", 0);
        bus.emit(c"other.namespace", key, 0);
        bus.emit(namespace, key, 1);
        assert_eq!(bus.next(&updates), Some(true));

        bus.set_owner(false);
        assert_eq!(bus.next(&updates), None);
        bus.set_owner(true);
        assert_eq!(bus.next(&updates), Some(true));

        // The asynchronous initial reply must not overwrite a live update.
        bus.hold_read();
        bus.set_owner(false);
        assert_eq!(bus.next(&updates), None);
        bus.set_owner(true);
        bus.wait_for_read();
        bus.emit(namespace, key, 0);
        assert_eq!(bus.next(&updates), Some(false));
        bus.reply();
        bus.emit(namespace, key, 0);
        assert_eq!(bus.next(&updates), Some(false));

        // The Rust callback must be released even if the portal never responds.
        bus.set_owner(false);
        assert_eq!(bus.next(&updates), None);
        bus.set_owner(true);
        bus.wait_for_read();
        drop(observer);
        assert_eq!(
            updates.recv_timeout(Duration::from_secs(3)),
            Err(mpsc::RecvTimeoutError::Disconnected)
        );
    }
}
