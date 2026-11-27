//! Bounded icon extraction for desktop search results.
#![deny(unsafe_code)]

mod appimage;
mod exe;

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

#[derive(Clone, Copy, PartialEq, Eq)]
pub enum EmbeddedIcon {
    Exe,
    AppImage,
}

impl EmbeddedIcon {
    pub fn for_path(path: &Path) -> Option<Self> {
        let extension = path.extension()?;
        if extension.eq_ignore_ascii_case("exe") {
            Some(Self::Exe)
        } else if extension.eq_ignore_ascii_case("AppImage") {
            Some(Self::AppImage)
        } else {
            None
        }
    }
}

/// Decode a resident file on a background thread. The supplied predicate lets
/// a cancelled search skip reading the file or entering the PE guest after a read.
pub fn decode(path: &Path, is_current: impl Fn() -> bool) -> Option<Vec<u8>> {
    static EXE: OnceLock<Option<exe::Decoder>> = OnceLock::new();
    static APPIMAGE: OnceLock<Option<appimage::Decoder>> = OnceLock::new();
    if !is_current() {
        return None;
    }
    let kind = EmbeddedIcon::for_path(path)?;
    #[cfg(target_os = "macos")]
    let _policy = macos::MaterializationPolicy::disable()?;
    match kind {
        EmbeddedIcon::Exe => {
            let decoder = EXE.get_or_init(exe::Decoder::new).as_ref()?;
            let bytes = snapshot(path)?;
            if !is_current() {
                return None;
            }
            decoder.decode(&bytes)
        }
        EmbeddedIcon::AppImage => {
            let decoder = APPIMAGE.get_or_init(appimage::Decoder::new).as_ref()?;
            let (file, len) = resident_file(path)?;
            decoder.decode(file, len)
        }
    }
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
