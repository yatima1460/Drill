//! Bounded icon extraction for desktop search results.
#![deny(unsafe_code)]

mod appimage;
mod bundle;
mod exe;
#[cfg(windows)]
mod wine_bundle;

#[cfg(windows)]
pub fn prepare_wine_icons() {
    wine_bundle::prepare();
}

use std::io::Read;
use std::path::Path;
use std::sync::OnceLock;
use wasmi::{Config, Engine, Module, StoreLimits, StoreLimitsBuilder};

pub const RGBA_BYTES: usize = 32 * 32 * 4;
const MAX_FILE: u64 = 16 * 1024 * 1024;

fn compile_guest(bytes: &[u8]) -> Option<Module> {
    let mut config = Config::default();
    config.consume_fuel(true);
    Module::new(&Engine::new(&config), bytes).ok()
}

fn guest_limits() -> StoreLimits {
    StoreLimitsBuilder::new()
        .memory_size(64 << 20)
        .instances(1)
        .memories(1)
        .tables(1)
        .build()
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum EmbeddedIcon {
    Exe,
    AppImage,
    AppBundle,
}

impl EmbeddedIcon {
    pub fn for_path(path: &Path) -> Option<Self> {
        Self::for_entry(path, false)
    }

    /// Classify using the metadata already recorded by the search. Only a
    /// directory can be an application bundle.
    pub fn for_entry(path: &Path, directory: bool) -> Option<Self> {
        let extension = path.extension()?;
        if directory {
            return extension
                .eq_ignore_ascii_case("app")
                .then_some(Self::AppBundle);
        }
        if extension.eq_ignore_ascii_case("exe") {
            Some(Self::Exe)
        } else if extension.eq_ignore_ascii_case("AppImage") {
            Some(Self::AppImage)
        } else {
            None
        }
    }

    /// Open and decode a resident resource on the background worker.
    pub fn decode(self, path: &Path, is_current: impl Fn() -> bool) -> Option<Vec<u8>> {
        static RESOURCE: OnceLock<Option<exe::Decoder>> = OnceLock::new();
        static APPIMAGE: OnceLock<Option<appimage::Decoder>> = OnceLock::new();
        if !is_current() {
            return None;
        }
        #[cfg(windows)]
        if self == Self::AppBundle && wine_bundle::running_under_wine() {
            return wine_bundle::decode(path, &is_current);
        }
        #[cfg(target_os = "macos")]
        let _policy = match self {
            Self::AppBundle => None, // The bundle reader also protects its directory traversal.
            _ => Some(macos::MaterializationPolicy::disable()?),
        };
        match self {
            Self::Exe | Self::AppBundle => {
                let (bytes, export) = if self == Self::AppBundle {
                    (bundle::snapshot(path, &is_current)?, "decode_icns")
                } else {
                    (snapshot(path)?, "decode")
                };
                if !is_current() {
                    return None;
                }
                RESOURCE
                    .get_or_init(exe::Decoder::new)
                    .as_ref()?
                    .decode(&bytes, export)
            }
            Self::AppImage => {
                let decoder = APPIMAGE.get_or_init(appimage::Decoder::new).as_ref()?;
                let (file, len) = resident_file(path)?;
                decoder.decode(file, len)
            }
        }
    }
}

/// macOS obtains application bundle icons from NSWorkspace. Only its regular
/// executable and AppImage files use the portable decoder.
pub fn decode(path: &Path, is_current: impl Fn() -> bool) -> Option<Vec<u8>> {
    EmbeddedIcon::for_path(path)?.decode(path, is_current)
}

fn resident_file(path: &Path) -> Option<(std::fs::File, u64)> {
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
    if !metadata.is_file() {
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
    Some((file, metadata.len()))
}

fn snapshot(path: &Path) -> Option<Vec<u8>> {
    let (file, len) = resident_file(path)?;
    if len > MAX_FILE {
        return None;
    }
    let mut bytes = Vec::new();
    file.take(MAX_FILE + 1).read_to_end(&mut bytes).ok()?;
    if bytes.len() as u64 > MAX_FILE {
        return None;
    }
    Some(bytes)
}

#[cfg(target_os = "macos")]
#[allow(unsafe_code)]
mod macos {
    // sys/resource.h. Swift dispatch queues can reuse a thread for unrelated work.
    const MATERIALIZE_DATALESS_FILES: i32 = 3;
    const THREAD: i32 = 1;
    const OFF: i32 = 1;

    unsafe extern "C" {
        fn getiopolicy_np(kind: i32, scope: i32) -> i32;
        fn setiopolicy_np(kind: i32, scope: i32, policy: i32) -> i32;
    }

    pub(super) struct MaterializationPolicy(i32);

    impl MaterializationPolicy {
        pub(super) fn disable() -> Option<Self> {
            // SAFETY: these calls access only the current thread's policy.
            let previous = unsafe { getiopolicy_np(MATERIALIZE_DATALESS_FILES, THREAD) };
            if previous < 0 {
                return None;
            }
            // SAFETY: OFF is a documented policy value for this kind and scope.
            let result = unsafe { setiopolicy_np(MATERIALIZE_DATALESS_FILES, THREAD, OFF) };
            if result != 0 {
                return None;
            }
            Some(Self(previous))
        }
    }

    impl Drop for MaterializationPolicy {
        fn drop(&mut self) {
            // SAFETY: this guard lives in the synchronous decode stack frame on
            // the thread whose previous policy we queried.
            unsafe { setiopolicy_np(MATERIALIZE_DATALESS_FILES, THREAD, self.0) };
        }
    }
}

#[cfg(test)]
#[path = "../../drill-core/src/test_directory.rs"]
mod test_directory;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn file_and_directory_formats_use_their_own_decoders() {
        for (name, file, directory) in [
            ("a.eXe", Some(EmbeddedIcon::Exe), None),
            ("a.AppImage", Some(EmbeddedIcon::AppImage), None),
            ("Journal.ApP", None, Some(EmbeddedIcon::AppBundle)),
            ("ordinary", None, None),
        ] {
            let path = Path::new(name);
            assert_eq!(EmbeddedIcon::for_path(path), file);
            assert_eq!(EmbeddedIcon::for_entry(path, true), directory);
        }
    }

    #[test]
    fn rejects_directory_and_large_file() {
        assert!(snapshot(&std::env::temp_dir()).is_none());
        let directory = crate::test_directory::private_temp_dir();
        let path = directory.path().join("large.exe");
        std::fs::File::create_new(&path)
            .unwrap()
            .set_len(MAX_FILE + 1)
            .unwrap();
        assert!(snapshot(&path).is_none());
    }
}
