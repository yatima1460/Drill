#![cfg(unix)]
#![deny(unsafe_op_in_unsafe_fn)]
//! C interface to Drill's search core for the experimental macOS frontend.

mod icons;

use drill_core::{default_roots_with_cancel, Entry, FileFilter, MatchKind, Search, SearchQuery};
use std::ffi::{c_char, c_void, CStr, CString, OsStr};
use std::os::unix::ffi::OsStrExt;
use std::path::PathBuf;
use std::ptr;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc::{self, Receiver, TryRecvError};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::UNIX_EPOCH;

const MAX_HITS_PER_POLL: u32 = 256;

enum Phase {
    Starting {
        receiver: Receiver<Result<Option<Search>, String>>,
        paused: Arc<Mutex<bool>>,
    },
    Searching(Search),
    Finished,
}

/// Opaque, single-owner handle. See `include/DrillSearch.h` for the ABI.
pub struct DrillSearch {
    phase: Phase,
    startup_cancel: Arc<AtomicBool>,
    paused: bool,
    error: Option<CString>,
}

impl DrillSearch {
    fn fail(&mut self, message: String) {
        self.error = Some(CString::new(message).unwrap_or_else(|_| c"Search failed".into()));
        self.phase = Phase::Finished;
    }

    fn check_startup(&mut self) {
        let Phase::Starting { receiver, .. } = &self.phase else {
            return;
        };
        match receiver.try_recv() {
            Ok(Ok(Some(search))) => {
                search.set_paused(self.paused);
                self.phase = Phase::Searching(search);
            }
            Ok(Ok(None)) => self.phase = Phase::Finished,
            Ok(Err(error)) => self.fail(error),
            Err(TryRecvError::Disconnected) => {
                self.fail("Search startup stopped unexpectedly".into())
            }
            Err(TryRecvError::Empty) => {}
        }
    }
}

impl Drop for DrillSearch {
    fn drop(&mut self) {
        // Core Search::drop stops traversal and wakes paused workers. Dropping
        // the startup receiver also drops a Search already sent but unpolled.
        self.startup_cancel.store(true, Ordering::Relaxed);
    }
}

fn start(
    text: String,
    apps: bool,
    root: Option<PathBuf>,
    cancel: Arc<AtomicBool>,
) -> Result<Option<Search>, String> {
    if cancel.load(Ordering::Relaxed) {
        return Ok(None);
    }
    let query = SearchQuery::parse(&text);
    if let Some(error) = query.error() {
        return Err(error.to_owned());
    }
    if query.is_empty() && !(apps && text.trim().is_empty()) {
        return Ok(None);
    }
    let roots = match root {
        Some(root) => vec![root],
        None => default_roots_with_cancel(&cancel),
    };
    let filter = if apps {
        FileFilter::MacBundles
    } else {
        FileFilter::All
    };
    Ok(Some(Search::start_filtered(query, roots, cancel, filter)))
}

/// Starts a search. Query parsing, root discovery and traversal run on workers.
///
/// # Safety
/// A non-null `query` must reference a readable NUL-terminated C string. For
/// `0 < root_len <= isize::MAX`, a non-null `root` must reference that many
/// readable bytes in a single allocation. Both inputs are borrowed for this call only.
#[no_mangle]
pub unsafe extern "C" fn drill_search_start(
    query: *const c_char,
    apps: bool,
    root: *const u8,
    root_len: usize,
) -> *mut DrillSearch {
    let cancel = Arc::new(AtomicBool::new(false));
    let mut handle = Box::new(DrillSearch {
        phase: Phase::Finished,
        startup_cancel: cancel.clone(),
        paused: false,
        error: None,
    });
    let spawn = || -> Result<Phase, String> {
        if query.is_null() {
            return Err("Missing search query".into());
        }
        // SAFETY: the caller supplies a terminated string for this call.
        let text = unsafe { CStr::from_ptr(query) }
            .to_str()
            .map_err(|_| "Search query must be UTF-8")?
            .to_owned();
        let root = if root_len == 0 {
            None
        } else {
            if root.is_null() || root_len > isize::MAX as usize {
                return Err("Invalid search root".into());
            }
            // SAFETY: input contract and length check above.
            let bytes = unsafe { std::slice::from_raw_parts(root, root_len) };
            if bytes.contains(&0) {
                return Err("Search root contains a NUL byte".into());
            }
            Some(PathBuf::from(OsStr::from_bytes(bytes)))
        };
        let (sender, receiver) = mpsc::sync_channel(1);
        let paused = Arc::new(Mutex::new(false));
        let startup_pause = paused.clone();
        thread::Builder::new()
            .name("drill-swift-start".into())
            .spawn(move || {
                let result = start(text, apps, root, cancel);
                // Serialize this one-shot handoff with pause requests. Workers
                // honor a pause during startup even if the UI stops polling.
                let requested_pause = startup_pause.lock().unwrap();
                if *requested_pause {
                    if let Ok(Some(search)) = &result {
                        search.set_paused(true);
                    }
                }
                let _ = sender.send(result);
            })
            .map_err(|error| format!("Could not start search: {error}"))?;
        Ok(Phase::Starting { receiver, paused })
    };
    match spawn() {
        Ok(phase) => handle.phase = phase,
        Err(error) => handle.fail(error),
    }
    Box::into_raw(handle)
}

/// Returns a borrowed UTF-8 error string or null.
///
/// # Safety
/// A non-null handle must come from `drill_search_start` and still be live.
/// The pointer returned is valid until the next mutable call on this handle.
#[no_mangle]
pub unsafe extern "C" fn drill_search_error(search: *const DrillSearch) -> *const c_char {
    // SAFETY: the caller owns the live handle and serializes calls.
    unsafe { search.as_ref() }
        .and_then(|handle| handle.error.as_deref())
        .map_or(ptr::null(), CStr::as_ptr)
}

pub type DrillHitCallback =
    unsafe extern "C" fn(*mut c_void, *const u8, usize, *const c_char, u8, bool, u64, i64);

fn modified_seconds(entry: &Entry) -> Option<i64> {
    match entry.modified?.duration_since(UNIX_EPOCH) {
        Ok(duration) => i64::try_from(duration.as_secs()).ok(),
        Err(error) => {
            // Round fractional timestamps down on both sides of the epoch.
            let duration = error.duration();
            let seconds = i64::try_from(duration.as_secs()).ok()?;
            (-seconds).checked_sub(i64::from(duration.subsec_nanos() != 0))
        }
    }
}

unsafe fn deliver(ctx: *mut c_void, callback: DrillHitCallback, rank: MatchKind, entry: Entry) {
    let path = entry.path.as_os_str().as_bytes();
    let modified = modified_seconds(&entry).unwrap_or(i64::MIN);
    let name = CString::new(entry.name).unwrap_or_else(|_| c"�".into());
    let rank = match rank {
        MatchKind::Exact => 0,
        MatchKind::Partial => 1,
    };
    // SAFETY: the caller supplies the callback/context. The
    // Entry's path and CString outlive this synchronous invocation.
    unsafe {
        callback(
            ctx,
            path.as_ptr(),
            path.len(),
            name.as_ptr(),
            rank,
            entry.is_dir,
            entry.size.unwrap_or(u64::MAX),
            modified,
        );
    }
}

/// Polls at most 256 hits. Only a disconnected, drained channel is complete.
///
/// # Safety
/// A non-null handle must be live and exclusively borrowed for this call. A
/// non-null callback must accept the arguments in the header, use a valid
/// context, and neither reenter this handle nor unwind across the ABI.
#[no_mangle]
pub unsafe extern "C" fn drill_search_poll(
    search: *mut DrillSearch,
    max_hits: u32,
    ctx: *mut c_void,
    callback: Option<DrillHitCallback>,
) -> i32 {
    // SAFETY: the caller owns the live handle and serializes calls.
    let Some(handle) = (unsafe { search.as_mut() }) else {
        return 1;
    };
    handle.check_startup();
    let Phase::Searching(search) = &handle.phase else {
        return i32::from(matches!(handle.phase, Phase::Finished));
    };
    let Some(callback) = callback.filter(|_| !handle.paused) else {
        return 0;
    };
    for _ in 0..max_hits.min(MAX_HITS_PER_POLL) {
        match search.try_recv_hit() {
            Ok((rank, entry)) => {
                // SAFETY: the callback and context satisfy the caller contract.
                unsafe { deliver(ctx, callback, rank, entry) };
            }
            Err(TryRecvError::Empty) => break,
            Err(TryRecvError::Disconnected) => {
                handle.phase = Phase::Finished;
                return 1;
            }
        }
    }
    0
}

/// Pauses or resumes the same search, including a pending startup.
///
/// # Safety
/// A non-null handle must be live and exclusively borrowed for this call.
#[no_mangle]
pub unsafe extern "C" fn drill_search_set_paused(search: *mut DrillSearch, paused: bool) {
    // SAFETY: the caller owns the live handle and serializes calls.
    if let Some(handle) = unsafe { search.as_mut() } {
        handle.paused = paused;
        match &handle.phase {
            Phase::Starting {
                paused: startup_pause,
                ..
            } => {
                *startup_pause.lock().unwrap() = paused;
                handle.check_startup();
            }
            Phase::Searching(search) => search.set_paused(paused),
            Phase::Finished => {}
        }
    }
}

/// Cancels and releases the handle without joining filesystem workers.
///
/// # Safety
/// A non-null handle must come from `drill_search_start`, must be freed exactly
/// once, and must never be used again. All earlier callbacks must have returned.
#[no_mangle]
pub unsafe extern "C" fn drill_search_free(search: *mut DrillSearch) {
    if !search.is_null() {
        // SAFETY: the caller transfers the unique Box allocation back to Rust.
        drop(unsafe { Box::from_raw(search) });
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::Duration;

    #[test]
    fn callback_copies_a_non_utf8_path_and_a_preepoch_timestamp() {
        #[derive(Default)]
        struct Captured {
            path: Vec<u8>,
            name: Vec<u8>,
            size: u64,
            modified: i64,
        }
        unsafe extern "C" fn receive(
            ctx: *mut c_void,
            path: *const u8,
            len: usize,
            name: *const c_char,
            _: u8,
            _: bool,
            size: u64,
            modified: i64,
        ) {
            // SAFETY: deliver borrows path and name during this invocation,
            // and the context is the live Captured below.
            unsafe {
                *ctx.cast::<Captured>() = Captured {
                    path: std::slice::from_raw_parts(path, len).into(),
                    name: CStr::from_ptr(name).to_bytes().into(),
                    size,
                    modified,
                };
            }
        }
        let mut captured = Captured::default();
        let path = OsStr::from_bytes(b"/example/x\xff");
        let entry = Entry {
            path: path.into(),
            name: "x�".into(),
            size: None,
            modified: Some(UNIX_EPOCH - Duration::from_millis(500)),
            is_dir: false,
        };
        // SAFETY: receive uses the unique Captured context only during deliver.
        unsafe {
            deliver(
                std::ptr::from_mut(&mut captured).cast(),
                receive,
                MatchKind::Partial,
                entry,
            )
        };
        assert_eq!(captured.path, path.as_bytes());
        assert_eq!(captured.name, "x�".as_bytes());
        assert_eq!(captured.size, u64::MAX);
        assert_eq!(captured.modified, -1);
    }
}
