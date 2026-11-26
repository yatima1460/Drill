//! Ask the operating system about an empty file with the same extension. The icon
//! provider never receives the path to an untrusted executable.
use std::fs::{self, File};
use std::io;
use std::path::{Path, PathBuf};

struct IconSample {
    path: PathBuf,
    _file: File,
}

impl IconSample {
    fn create(path: PathBuf) -> io::Result<Self> {
        let mut options = File::options();
        options.read(true).write(true).create_new(true);
        #[cfg(unix)]
        std::os::unix::fs::OpenOptionsExt::mode(&mut options, 0o600);
        #[cfg(windows)]
        std::os::windows::fs::OpenOptionsExt::custom_flags(
            &mut options,
            windows_sys::Win32::Storage::FileSystem::FILE_ATTRIBUTE_TEMPORARY,
        );
        let file = options.open(&path)?;
        Ok(Self { path, _file: file })
    }
}

impl Drop for IconSample {
    fn drop(&mut self) {
        let _ = fs::remove_file(&self.path);
    }
}

#[cfg(windows)]
#[allow(unsafe_code)]
fn windows_sample_name() -> Option<String> {
    #[repr(C)]
    #[derive(Default)]
    struct Guid {
        data1: u32,
        data2: u16,
        data3: u16,
        data4: [u8; 8],
    }

    #[link(name = "rpcrt4")]
    unsafe extern "system" {
        fn UuidCreate(uuid: *mut Guid) -> i32;
    }

    const RPC_S_OK: i32 = 0;
    const RPC_S_UUID_LOCAL_ONLY: i32 = 1824;

    let mut guid = Guid::default();
    // SAFETY: guid has the Windows GUID layout and is writable for the duration of the call.
    let status = unsafe { UuidCreate(&mut guid) };
    if !matches!(status, RPC_S_OK | RPC_S_UUID_LOCAL_ONLY) {
        return None;
    }

    Some(format!(
        "drill-{:08x}{:04x}{:04x}{:016x}",
        guid.data1,
        guid.data2,
        guid.data3,
        u64::from_be_bytes(guid.data4)
    ))
}

pub(super) fn icon(sample_name: &str, size: u16) -> Option<file_icon_provider::Icon> {
    let extension = Path::new(sample_name).extension()?;
    #[cfg(target_os = "macos")]
    let name = format!("drill-{}", objc2_foundation::NSUUID::UUID().UUIDString());
    #[cfg(windows)]
    let name = windows_sample_name()?;
    let path = std::env::temp_dir().join(name).with_extension(extension);
    let sample = IconSample::create(path).ok()?;
    file_icon_provider::get_file_icon(&sample.path, size).ok()
}

#[cfg(test)]
mod tests {
    use super::*;
    #[cfg(unix)]
    use std::os::unix::fs::{symlink, PermissionsExt};

    #[test]
    fn owns_only_the_file_it_created() {
        let dir = crate::test_directory::private_temp_dir();
        let path = dir.path().join("sample.exe");
        let sample = IconSample::create(path.clone()).unwrap();
        #[cfg(unix)]
        assert_eq!(fs::metadata(&path).unwrap().permissions().mode() & 0o077, 0);
        assert!(IconSample::create(path.clone()).is_err());
        assert!(path.exists());
        drop(sample);
        assert!(!path.exists());
    }

    #[cfg(unix)]
    #[test]
    fn never_follows_or_removes_an_existing_symlink() {
        let dir = crate::test_directory::private_temp_dir();
        let path = dir.path().join("sample.exe");
        let target = dir.path().join("existing");
        fs::write(&target, b"preserve").unwrap();
        symlink(&target, &path).unwrap();
        assert!(IconSample::create(path.clone()).is_err());
        assert!(path.is_symlink());
        assert_eq!(fs::read(target).unwrap(), b"preserve");
    }

    #[test]
    fn associated_icons_match_the_previous_lookup() {
        let directory = crate::test_directory::private_temp_dir();
        for name in ["sample.exe", "sample.AppImage"] {
            let previous = directory.path().join(name);
            let _file = File::create_new(&previous).unwrap();
            let expected = file_icon_provider::get_file_icon(&previous, 64).unwrap();
            let actual = icon(name, 64).unwrap();
            assert_eq!((actual.width, actual.height), (64, 64));
            assert!(
                actual.pixels == expected.pixels,
                "different icon for {name}"
            );
        }
    }
}
