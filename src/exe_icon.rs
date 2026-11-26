//! Queue icon work off the egui thread and drop stale requests after a search.
use drill_icons::EmbeddedIcon;
use eframe::egui;
use std::{
    path::{Path, PathBuf},
    sync::{
        atomic::{AtomicU64, Ordering},
        mpsc, Arc,
    },
};
pub fn is_exe(path: &Path) -> bool {
    EmbeddedIcon::for_path(path) == Some(EmbeddedIcon::Exe)
}
pub fn is_appimage(path: &Path) -> bool {
    EmbeddedIcon::for_path(path) == Some(EmbeddedIcon::AppImage)
}
#[derive(Debug, PartialEq, Eq)]
pub enum IconRoute {
    Platform,
    Folder,
    TypeIcon,
    Decode,
}
pub fn icon_route(path: &Path, is_dir: bool, enabled: bool) -> IconRoute {
    if !is_exe(path) && !is_appimage(path) {
        IconRoute::Platform
    } else if is_dir {
        IconRoute::Folder
    } else if enabled {
        IconRoute::Decode
    } else {
        IconRoute::TypeIcon
    }
}
struct Request {
    generation: u64,
    path: PathBuf,
    context: egui::Context,
}
pub struct Response {
    pub generation: u64,
    pub path: PathBuf,
    pub pixels: Option<Vec<u8>>,
}
pub struct Worker {
    sender: mpsc::SyncSender<Request>,
    pub receiver: mpsc::Receiver<Response>,
    generation: Arc<AtomicU64>,
}
pub enum RequestState {
    Queued,
    Full,
    Closed,
}

impl Worker {
    pub fn new() -> Self {
        let (sender, requests) = mpsc::sync_channel::<Request>(16);
        let (response, receiver) = mpsc::channel();
        let generation = Arc::new(AtomicU64::new(0));
        let current = generation.clone();
        std::thread::spawn(move || {
            while let Ok(request) = requests.recv() {
                let is_current = || current.load(Ordering::Relaxed) == request.generation;
                if !is_current() {
                    continue;
                }
                let pixels = drill_icons::decode(&request.path, is_current);
                if response
                    .send(Response {
                        generation: request.generation,
                        path: request.path,
                        pixels,
                    })
                    .is_err()
                {
                    break;
                }
                request.context.request_repaint();
            }
        });
        Self {
            sender,
            receiver,
            generation,
        }
    }
    pub fn invalidate(&self, generation: u64) {
        self.generation.store(generation, Ordering::Relaxed);
    }
    pub fn request(&self, generation: u64, path: PathBuf, context: egui::Context) -> RequestState {
        match self.sender.try_send(Request {
            generation,
            path,
            context,
        }) {
            Ok(()) => RequestState::Queued,
            Err(mpsc::TrySendError::Full(_)) => RequestState::Full,
            Err(mpsc::TrySendError::Disconnected(_)) => RequestState::Closed,
        }
    }
}
#[cfg(test)]
pub(super) fn write_pe32_fixture(directory: &crate::test_directory::TestDirectory) -> PathBuf {
    use std::io::Write;

    let path = directory.path().join("sample.exe");
    std::fs::File::create_new(&path)
        .unwrap()
        .write_all(include_bytes!(
            "../tools/exe-icon-wasm/tests/fixtures/icon-pe32.exe"
        ))
        .unwrap();
    path
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn routes_embedded_icon_formats() {
        assert!(is_exe(Path::new("APP.EXE")));
        assert!(!is_exe(Path::new("APP.EXE.txt")));
        assert_eq!(
            icon_route(Path::new("folder.AppImage"), true, true),
            IconRoute::Folder
        );
        assert_eq!(
            icon_route(Path::new("build.AppImage.txt"), false, true),
            IconRoute::Platform
        );
        assert_eq!(
            icon_route(Path::new("folder.exe"), true, true),
            IconRoute::Folder
        );
        assert_eq!(
            icon_route(Path::new("file.exe"), false, true),
            IconRoute::Decode
        );
        assert_eq!(
            icon_route(Path::new("file.exe"), false, false),
            IconRoute::TypeIcon
        );
    }
    #[test]
    fn worker_reads_and_decodes_resident_executable() {
        let directory = crate::test_directory::private_temp_dir();
        let path = write_pe32_fixture(&directory);
        let worker = Worker::new();
        assert!(matches!(
            worker.request(0, path.clone(), egui::Context::default()),
            RequestState::Queued
        ));
        let result = worker
            .receiver
            .recv_timeout(std::time::Duration::from_secs(10))
            .expect("icon worker did not respond");
        assert_eq!(result.path, path);
        let pixels = result.pixels.expect("worker did not extract icon");
        assert_eq!(&pixels[..4], &[0, 255, 0, 255]);
    }
}
