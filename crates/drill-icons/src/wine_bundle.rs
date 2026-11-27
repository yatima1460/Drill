//! Private pipes supplied by the Unix launcher. Wine never opens a bundle here.
#![allow(unsafe_code)]

use std::ffi::{c_void, OsStr};
use std::fs::File;
use std::io::{self, Read, Write};
use std::os::windows::ffi::OsStrExt;
use std::os::windows::io::{AsRawHandle, FromRawHandle};
use std::path::{Component, Path, Prefix};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{mpsc, OnceLock};
use std::time::{Duration, Instant};
use windows_sys::Win32::Foundation::{SetHandleInformation, HANDLE, HANDLE_FLAG_INHERIT};
use windows_sys::Win32::Storage::FileSystem::{GetFileType, FILE_TYPE_PIPE};

const MARKER: &str = "DRILL_WINE_BUNDLE_PIPE";
const MAX_PATH_UNITS: u32 = 32_767;
const IO_TIMEOUT: Duration = Duration::from_secs(2);
const CANCEL_POLL: Duration = Duration::from_millis(10);

#[link(name = "kernel32")]
unsafe extern "system" {
    fn GetModuleHandleA(name: *const u8) -> HANDLE;
    fn GetProcAddress(module: HANDLE, name: *const u8) -> *const c_void;
    fn SetStdHandle(which: u32, handle: HANDLE) -> i32;
}

pub(super) fn running_under_wine() -> bool {
    static WINE: OnceLock<bool> = OnceLock::new();
    *WINE.get_or_init(|| {
        // SAFETY: both names are terminated. ntdll stays loaded for process lifetime.
        unsafe {
            let module = GetModuleHandleA(c"ntdll.dll".as_ptr().cast());
            !module.is_null()
                && !GetProcAddress(module, c"wine_get_version".as_ptr().cast()).is_null()
        }
    })
}

struct Request {
    frame: Vec<u8>,
    reply: mpsc::SyncSender<Option<Vec<u8>>>,
}

struct Client {
    requests: mpsc::SyncSender<Request>,
    timed_out: AtomicBool,
}

static CLIENT: OnceLock<Option<Client>> = OnceLock::new();

/// Called once at application startup, before launching children or using stdio.
pub(super) fn prepare() {
    CLIENT.get_or_init(|| {
        if !running_under_wine() || std::env::var_os(MARKER).as_deref() != Some(OsStr::new("1")) {
            return None;
        }
        // Windows synchronizes environment changes. Descendants must not opt in.
        std::env::remove_var(MARKER);
        let input = io::stdin().as_raw_handle();
        let output = io::stdout().as_raw_handle();
        let error = io::stderr().as_raw_handle();
        if input == output || input == error || output == error {
            return None;
        }
        for handle in [input, output] {
            // SAFETY: these APIs inspect standard handles and reject invalid handles.
            if unsafe { GetFileType(handle) } != FILE_TYPE_PIPE {
                return None;
            }
        }
        for handle in [input, output] {
            // SAFETY: the verified pipe is still the launcher's standard handle.
            if unsafe { SetHandleInformation(handle, HANDLE_FLAG_INHERIT, 0) } == 0 {
                return None;
            }
        }
        let input = take_standard_pipe(-10_i32 as u32, input)?;
        let output = take_standard_pipe(-11_i32 as u32, output)?;
        Client::start(input, output)
    });
}

fn take_standard_pipe(which: u32, pipe: HANDLE) -> Option<File> {
    // SAFETY: release this slot before taking ownership of its distinct pipe.
    // Future child creation and ordinary stdio must not use the private channel.
    if unsafe { SetStdHandle(which, std::ptr::null_mut()) } == 0 {
        return None;
    }
    // SAFETY: the detached, non-inheritable handle is now owned only by this File.
    Some(unsafe { File::from_raw_handle(pipe) })
}

impl Client {
    fn start(mut input: File, mut output: File) -> Option<Self> {
        // Only this thread ever touches the pipes. An abandoned reply is consumed
        // completely before it accepts another request, including after cancellation.
        let (requests, jobs) = mpsc::sync_channel::<Request>(0);
        std::thread::Builder::new()
            .name("Drill Wine icons".into())
            .spawn(move || {
                while let Ok(request) = jobs.recv() {
                    let Ok(pixels) = exchange(&request.frame, &mut input, &mut output) else {
                        break;
                    };
                    let _ = request.reply.send(pixels);
                }
            })
            .ok()?;
        Some(Self {
            requests,
            timed_out: AtomicBool::new(false),
        })
    }

    fn request(&self, frame: Vec<u8>, current: &impl Fn() -> bool) -> Option<Vec<u8>> {
        let deadline = Instant::now() + IO_TIMEOUT;
        let interval = || {
            if !current() || self.timed_out.load(Ordering::Relaxed) {
                return None;
            }
            let left = deadline.saturating_duration_since(Instant::now());
            if left.is_zero() {
                // A stalled peer can occupy at most the single pipe worker. All
                // subsequent rows immediately use their file-type fallback.
                self.timed_out.store(true, Ordering::Relaxed);
                return None;
            }
            Some(left.min(CANCEL_POLL))
        };
        let (reply, result) = mpsc::sync_channel(1);
        let mut request = Request { frame, reply };
        loop {
            let wait = interval()?;
            match self.requests.try_send(request) {
                Ok(()) => break,
                Err(mpsc::TrySendError::Disconnected(_)) => return None,
                Err(mpsc::TrySendError::Full(pending)) => {
                    request = pending;
                    std::thread::sleep(wait);
                }
            }
        }
        loop {
            match result.recv_timeout(interval()?) {
                Ok(pixels) => return pixels.filter(|_| current()),
                Err(mpsc::RecvTimeoutError::Disconnected) => return None,
                Err(mpsc::RecvTimeoutError::Timeout) => {}
            }
        }
    }
}

pub(super) fn decode(path: &Path, current: &impl Fn() -> bool) -> Option<Vec<u8>> {
    let client = CLIENT.get()?.as_ref()?;
    if !current() || client.timed_out.load(Ordering::Relaxed) {
        return None;
    }
    client.request(frame(path)?, current)
}

fn frame(path: &Path) -> Option<Vec<u8>> {
    let Component::Prefix(prefix) = path.components().next()? else {
        return None;
    };
    if !matches!(prefix.kind(), Prefix::Disk(_)) || !path.is_absolute() {
        return None;
    }
    let mut bytes = b"DRILICON\0\0\0\0".to_vec();
    let mut count = 0_u32;
    for unit in path.as_os_str().encode_wide() {
        if unit == 0 || count == MAX_PATH_UNITS {
            return None;
        }
        bytes.extend_from_slice(&unit.to_le_bytes());
        count += 1;
    }
    bytes[8..12].copy_from_slice(&count.to_le_bytes());
    Some(bytes)
}

fn exchange(
    frame: &[u8],
    input: &mut impl Read,
    output: &mut impl Write,
) -> io::Result<Option<Vec<u8>>> {
    output.write_all(frame)?;
    output.flush()?;
    let mut status = [0];
    input.read_exact(&mut status)?;
    match status[0] {
        0 => Ok(None),
        1 => {
            let mut pixels = vec![0; crate::RGBA_BYTES];
            input.read_exact(&mut pixels)?;
            Ok(Some(pixels))
        }
        _ => Err(io::ErrorKind::InvalidData.into()),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn frames_use_counted_utf16_and_only_drive_absolute_paths() {
        let bytes = frame(Path::new(r"Z:\🟢.app")).unwrap();
        assert_eq!(&bytes[..12], b"DRILICON\x09\0\0\0");
        assert_eq!(
            &bytes[12..],
            &[90, 0, 58, 0, 92, 0, 61, 216, 226, 223, 46, 0, 97, 0, 112, 0, 112, 0]
        );
        for invalid in [
            "C:relative.app",
            r"\\host\share\file.app",
            r"\\?\C:\file.app",
            "C:\\a\0b.app",
        ] {
            assert!(frame(Path::new(invalid)).is_none());
        }
        let max = format!(r"C:\{}", "a".repeat(MAX_PATH_UNITS as usize - 3));
        assert!(frame(Path::new(&max)).is_some());
        assert!(frame(Path::new(&(max + "a"))).is_none());
    }

    #[test]
    fn consumes_one_reply_and_rejects_malformed_or_incomplete_frames() {
        let pixels = vec![43; crate::RGBA_BYTES];
        let wire = [&[0, 1][..], &pixels, &[7]].concat();
        let mut input = wire.as_slice();
        let mut output = Vec::new();
        assert!(exchange(b"A", &mut input, &mut output).unwrap().is_none());
        assert_eq!(
            exchange(b"B", &mut input, &mut output).unwrap(),
            Some(pixels)
        );
        assert_eq!(
            exchange(b"C", &mut input, &mut output).unwrap_err().kind(),
            io::ErrorKind::InvalidData
        );
        assert_eq!(output, b"ABC");
        for mut truncated in [&[][..], &[1, 2, 3]] {
            assert_eq!(
                exchange(b"D", &mut truncated, &mut output)
                    .unwrap_err()
                    .kind(),
                io::ErrorKind::UnexpectedEof
            );
        }
    }
}
