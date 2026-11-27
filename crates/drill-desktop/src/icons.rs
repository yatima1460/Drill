//! Asynchronous embedded icons for rows displayed by the native desktop views.
use drill_icons::EmbeddedIcon;
use std::cell::OnceCell;
use std::collections::{HashMap, HashSet, VecDeque};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{mpsc, Arc};

const QUEUE_SIZE: usize = 16;
const CACHE_SIZE: usize = 256;

pub(crate) enum IconResult<'a> {
    Pending,
    Ready(&'a [u8]),
    Fallback,
}

struct Request {
    generation: u64,
    path: PathBuf,
}

struct Response {
    request: Request,
    pixels: Option<Vec<u8>>,
}

struct Worker {
    requests: mpsc::SyncSender<Request>,
    responses: mpsc::Receiver<Response>,
}

impl Worker {
    fn start(generation: Arc<AtomicU64>) -> Option<Self> {
        let (requests, jobs) = mpsc::sync_channel::<Request>(QUEUE_SIZE);
        let (completed, responses) = mpsc::sync_channel(QUEUE_SIZE);
        std::thread::Builder::new()
            .name("Drill icons".into())
            .spawn(move || {
                for request in jobs {
                    let current = || generation.load(Ordering::Relaxed) == request.generation;
                    let pixels = drill_icons::decode(&request.path, current);
                    // A completion also wakes a view that encountered a full queue,
                    // even when clear() cancelled every job in that queue.
                    if completed.send(Response { request, pixels }).is_err() {
                        break;
                    }
                }
            })
            .ok()?;
        Some(Self {
            requests,
            responses,
        })
    }
}

pub(crate) struct EmbeddedIcons {
    worker: OnceCell<Option<Worker>>,
    generation: Arc<AtomicU64>,
    enabled: (bool, bool),
    pending: HashSet<PathBuf>,
    // Cache failed decodes as well, so repainting cannot repeatedly open a bad file.
    cache: HashMap<PathBuf, Option<Vec<u8>>>,
    insertion_order: VecDeque<PathBuf>,
}

impl EmbeddedIcons {
    pub(crate) fn new() -> Self {
        Self {
            worker: OnceCell::new(),
            generation: Arc::new(AtomicU64::new(0)),
            enabled: (true, true),
            pending: HashSet::new(),
            cache: HashMap::new(),
            insertion_order: VecDeque::new(),
        }
    }

    pub(crate) fn clear(&mut self) {
        self.generation.fetch_add(1, Ordering::Relaxed);
        self.pending.clear();
        self.cache.clear();
        self.insertion_order.clear();
    }

    pub(crate) fn request(&mut self, path: &Path, exe: bool, appimage: bool) -> IconResult<'_> {
        if self.enabled != (exe, appimage) {
            self.enabled = (exe, appimage);
            self.clear();
        }
        let enabled = match EmbeddedIcon::for_path(path) {
            Some(EmbeddedIcon::Exe) => exe,
            Some(EmbeddedIcon::AppImage) => appimage,
            None => false,
        };
        if !enabled {
            return IconResult::Fallback;
        }
        if let Some(cached) = self.cache.get(path) {
            return match cached {
                Some(pixels) => IconResult::Ready(pixels),
                None => IconResult::Fallback,
            };
        }
        if self.pending.contains(path) {
            return IconResult::Pending;
        }
        let Some(worker) = self
            .worker
            .get_or_init(|| Worker::start(Arc::clone(&self.generation)))
        else {
            return IconResult::Fallback;
        };
        let request = Request {
            generation: self.generation.load(Ordering::Relaxed),
            path: path.to_owned(),
        };
        match worker.requests.try_send(request) {
            Ok(()) => {
                self.pending.insert(path.to_owned());
                IconResult::Pending
            }
            Err(mpsc::TrySendError::Full(_)) => IconResult::Pending,
            Err(mpsc::TrySendError::Disconnected(_)) => IconResult::Fallback,
        }
    }

    /// Called by the UI timer. Completions for a previous search never remove
    /// a current request, even if both searches found the same path.
    pub(crate) fn poll(&mut self) -> bool {
        let Some(Some(worker)) = self.worker.get() else {
            return false;
        };
        let mut changed = false;
        loop {
            match worker.responses.try_recv() {
                Ok(Response { request, pixels }) => {
                    changed = true;
                    if request.generation != self.generation.load(Ordering::Relaxed) {
                        continue;
                    }
                    self.pending.remove(&request.path);
                    if self.cache.len() == CACHE_SIZE {
                        let oldest = self.insertion_order.pop_front().expect("cached icon");
                        self.cache.remove(&oldest);
                    }
                    self.insertion_order.push_back(request.path.clone());
                    self.cache.insert(request.path, pixels);
                }
                Err(mpsc::TryRecvError::Empty) => break,
                Err(mpsc::TryRecvError::Disconnected) => {
                    changed |= !self.pending.is_empty();
                    self.pending.clear();
                    self.worker = OnceCell::from(None);
                    break;
                }
            }
        }
        changed
    }
}

impl Drop for EmbeddedIcons {
    fn drop(&mut self) {
        // Releasing the channels also wakes a worker waiting to send or receive.
        self.generation.fetch_add(1, Ordering::Relaxed);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::{Duration, Instant};

    #[test]
    fn ignores_unrelated_extensions_and_disabled_formats() {
        let mut icons = EmbeddedIcons::new();
        for (path, exe, appimage) in [
            ("photo.ExE.txt", true, true),
            ("folder.AppImage.txt", true, true),
            ("Program.eXe", false, true),
            ("Program.aPpImAgE", true, false),
        ] {
            assert!(matches!(
                icons.request(Path::new(path), exe, appimage),
                IconResult::Fallback
            ));
        }
        assert!(icons.worker.get().is_none());
    }

    #[test]
    fn worker_serves_both_wasm_formats_and_caches_failures() {
        let tools = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../tools");
        let mut icons = EmbeddedIcons::new();
        for (fixture, valid) in [
            ("exe-icon-wasm/tests/fixtures/icon-pe32.exe", true),
            (
                "appimage-icon-wasm/tests/fixtures/linked-png.AppImage",
                true,
            ),
            ("appimage-icon-wasm/tests/fixtures/cyclic.AppImage", false),
        ] {
            let path = tools.join(fixture);
            assert!(matches!(
                icons.request(&path, true, true),
                IconResult::Pending
            ));
            let deadline = Instant::now() + Duration::from_secs(10);
            while !icons.poll() {
                assert!(Instant::now() < deadline, "icon worker did not respond");
                std::thread::sleep(Duration::from_millis(1));
            }
            match icons.request(&path, true, true) {
                IconResult::Ready(pixels) => {
                    assert!(valid);
                    assert_eq!(pixels.len(), drill_icons::RGBA_BYTES);
                    assert_eq!(&pixels[..4], &[0, 255, 0, 255]);
                }
                IconResult::Fallback => assert!(!valid),
                IconResult::Pending => panic!("completed request was submitted again"),
            }
        }
    }

    #[test]
    fn stale_completion_cannot_overwrite_reissued_request() {
        let (requests, jobs) = mpsc::sync_channel(1);
        let (completed, responses) = mpsc::sync_channel(1);
        let mut icons = EmbeddedIcons::new();
        icons.worker = OnceCell::from(Some(Worker {
            requests,
            responses,
        }));
        let path = Path::new("program.exe");
        icons.request(path, true, true);
        icons.request(Path::new("other.exe"), true, true);
        assert_eq!(
            icons.pending.len(),
            1,
            "full queues must allow a later retry"
        );
        let old = jobs.try_recv().unwrap();
        icons.clear();
        icons.request(path, true, true);
        completed
            .send(Response {
                request: old,
                pixels: None,
            })
            .unwrap();
        assert!(icons.poll(), "queue space is now available");
        assert!(matches!(
            icons.request(path, true, true),
            IconResult::Pending
        ));
        let current = jobs.try_recv().unwrap();
        assert!(jobs.try_recv().is_err(), "no duplicate work");
        completed
            .send(Response {
                request: current,
                pixels: Some(vec![42; drill_icons::RGBA_BYTES]),
            })
            .unwrap();
        assert!(icons.poll());
        assert!(matches!(icons.request(path, true, true), IconResult::Ready(p) if p[0] == 42));
        assert!(matches!(
            icons.request(path, false, true),
            IconResult::Fallback
        ));
        assert!(icons.cache.is_empty());
    }
}
