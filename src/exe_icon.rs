//! Isolated, bounded extraction of untrusted executable icons.
use eframe::egui;
use std::{
    io::Read,
    path::{Path, PathBuf},
    sync::{
        atomic::{AtomicU64, Ordering},
        mpsc, Arc,
    },
};
use wasmi::{Config, Engine, Linker, Module, Store, StoreLimits, StoreLimitsBuilder};

const MAX_FILE: u64 = 16 * 1024 * 1024;
const PIXELS: usize = 32 * 32 * 4;
const FUEL: u64 = 80_000_000;

pub fn is_exe(path: &Path) -> bool {
    path.extension()
        .is_some_and(|ext| ext.eq_ignore_ascii_case("exe"))
}
#[derive(Debug, PartialEq, Eq)]
pub enum IconRoute {
    Platform,
    Folder,
    TypeIcon,
    Decode,
}
pub fn icon_route(path: &Path, is_dir: bool, enabled: bool) -> IconRoute {
    if !is_exe(path) {
        IconRoute::Platform
    } else if is_dir {
        IconRoute::Folder
    } else if enabled {
        IconRoute::Decode
    } else {
        IconRoute::TypeIcon
    }
}
fn snapshot(path: &Path) -> Option<Vec<u8>> {
    let mut options = std::fs::OpenOptions::new();
    options.read(true);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.custom_flags(libc::O_NONBLOCK | libc::O_NOFOLLOW);
    }
    #[cfg(windows)]
    {
        use std::os::windows::fs::OpenOptionsExt;
        use windows_sys::Win32::Storage::FileSystem::{
            FILE_FLAG_OPEN_NO_RECALL, FILE_FLAG_OPEN_REPARSE_POINT,
        };
        options.custom_flags(FILE_FLAG_OPEN_NO_RECALL | FILE_FLAG_OPEN_REPARSE_POINT);
    }
    let file = options.open(path).ok()?;
    let metadata = file.metadata().ok()?;
    if !metadata.is_file() || metadata.len() > MAX_FILE {
        return None;
    }
    #[cfg(windows)]
    {
        use std::os::windows::fs::MetadataExt;
        use windows_sys::Win32::Storage::FileSystem::{
            FILE_ATTRIBUTE_OFFLINE, FILE_ATTRIBUTE_RECALL_ON_DATA_ACCESS,
            FILE_ATTRIBUTE_RECALL_ON_OPEN, FILE_ATTRIBUTE_REPARSE_POINT,
        };
        if metadata.file_attributes()
            & (FILE_ATTRIBUTE_OFFLINE
                | FILE_ATTRIBUTE_RECALL_ON_DATA_ACCESS
                | FILE_ATTRIBUTE_RECALL_ON_OPEN
                | FILE_ATTRIBUTE_REPARSE_POINT)
            != 0
        {
            return None;
        }
    }
    let mut bytes = Vec::new();
    file.take(MAX_FILE + 1).read_to_end(&mut bytes).ok()?;
    if bytes.len() as u64 > MAX_FILE {
        return None;
    }
    Some(bytes)
}

struct Decoder {
    engine: Engine,
    module: Module,
}
impl Decoder {
    fn new() -> Option<Self> {
        let mut config = Config::default();
        config.consume_fuel(true);
        let engine = Engine::new(&config);
        let module = Module::new(&engine, &include_bytes!("assets/exe-icon.wasm")[..]).ok()?;
        // The fixed decoder must not receive filesystem, process, network, or any other host imports.
        if module.imports().next().is_some() {
            return None;
        }
        Some(Self { engine, module })
    }
    fn decode(&self, bytes: &[u8]) -> Option<Vec<u8>> {
        let limits = StoreLimitsBuilder::new()
            .memory_size(64 * 1024 * 1024)
            .instances(1)
            .memories(1)
            .tables(1)
            .build();
        let mut store = Store::new(&self.engine, limits);
        store.limiter(|limits: &mut StoreLimits| limits);
        store.set_fuel(FUEL).ok()?;
        let linker = Linker::new(&self.engine);
        let instance = linker
            .instantiate_and_start(&mut store, &self.module)
            .ok()?;
        let memory = instance.get_memory(&store, "memory")?;
        let allocate = instance
            .get_typed_func::<u32, u32>(&store, "allocate")
            .ok()?;
        let decode = instance
            .get_typed_func::<(u32, u32), u32>(&store, "decode")
            .ok()?;
        let len = u32::try_from(bytes.len()).ok()?;
        let input = allocate.call(&mut store, len).ok()?;
        memory.write(&mut store, input as usize, bytes).ok()?;
        let output = decode.call(&mut store, (input, len)).ok()?;
        if output == 0 {
            return None;
        }
        let mut pixels = vec![0; PIXELS];
        memory.read(&store, output as usize, &mut pixels).ok()?;
        Some(pixels)
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

#[cfg(target_os = "macos")]
#[allow(unsafe_code)]
fn prevent_cloud_materialization() -> bool {
    unsafe extern "C" {
        fn setiopolicy_np(kind: i32, scope: i32, policy: i32) -> i32;
    }
    // SAFETY: this sets a documented I/O policy only on the dedicated worker thread.
    unsafe { setiopolicy_np(3, 1, 1) == 0 }
}
#[cfg(not(target_os = "macos"))]
fn prevent_cloud_materialization() -> bool {
    true
}
impl Worker {
    pub fn new() -> Self {
        let (sender, requests) = mpsc::sync_channel::<Request>(16);
        let (response, receiver) = mpsc::channel();
        let generation = Arc::new(AtomicU64::new(0));
        let current = generation.clone();
        std::thread::spawn(move || {
            let decoder = if prevent_cloud_materialization() {
                Decoder::new()
            } else {
                None
            };
            while let Ok(request) = requests.recv() {
                if current.load(Ordering::Relaxed) != request.generation {
                    continue;
                }
                let pixels = decoder.as_ref().and_then(|d| {
                    snapshot(&request.path).and_then(|bytes| {
                        if current.load(Ordering::Relaxed) == request.generation {
                            d.decode(&bytes)
                        } else {
                            None
                        }
                    })
                });
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
pub(super) fn temporary_pe32() -> tempfile::NamedTempFile {
    use std::io::Write;
    let mut file = tempfile::Builder::new().suffix(".exe").tempfile().unwrap();
    file.write_all(include_bytes!(
        "../tools/exe-icon-wasm/tests/fixtures/icon-pe32.exe"
    ))
    .unwrap();
    file
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn malformed_input_is_rejected_and_decoder_has_no_imports() {
        let decoder = Decoder::new().expect("decoder must instantiate");
        assert!(decoder.decode(b"MZ not an executable").is_none());
        assert!(is_exe(Path::new("APP.EXE")));
        assert!(!is_exe(Path::new("APP.EXE.txt")));
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
    fn extracts_pe32_and_pe64_icons_inside_the_guest() {
        let decoder = Decoder::new().expect("decoder must instantiate");
        for fixture in [
            &include_bytes!("../tools/exe-icon-wasm/tests/fixtures/icon-pe32.exe")[..],
            &include_bytes!("../tools/exe-icon-wasm/tests/fixtures/icon-pe64.exe")[..],
        ] {
            let pixels = decoder.decode(fixture).expect("valid embedded icon");
            assert_eq!(pixels.len(), PIXELS);
            assert_eq!(&pixels[..4], &[0, 255, 0, 255]);
        }
    }

    #[test]
    fn worker_reads_and_decodes_resident_executable() {
        let file = temporary_pe32();
        let worker = Worker::new();
        let path = file.path().to_path_buf();
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
    #[test]
    fn malformed_resource_headers_do_not_escape_or_crash_decoder() {
        let decoder = Decoder::new().expect("decoder must instantiate");
        let fixture = include_bytes!("../tools/exe-icon-wasm/tests/fixtures/icon-pe32.exe");
        for offset in [0x3c, 0x80, 0x100, 0x200, 0x400, 0x800] {
            let mut input = fixture.to_vec();
            for byte in &mut input[offset..offset + 4] {
                *byte = 0xff;
            }
            if let Some(pixels) = decoder.decode(&input) {
                assert_eq!(pixels.len(), PIXELS);
            }
        }
    }
    #[test]
    fn rejects_directory_and_large_file() {
        assert!(snapshot(&std::env::temp_dir()).is_none());
        let file = tempfile::NamedTempFile::new().unwrap();
        file.as_file().set_len(MAX_FILE + 1).unwrap();
        assert!(snapshot(file.path()).is_none());
    }
}
