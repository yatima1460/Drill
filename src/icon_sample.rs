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

pub(super) fn icon(sample_name: &str, size: u16) -> Option<file_icon_provider::Icon> {
    let extension = Path::new(sample_name).extension()?;
    #[cfg(target_os = "macos")]
    let name = format!("drill-{}", objc2_foundation::NSUUID::UUID().UUIDString());
    #[cfg(windows)]
    let name = format!("drill-{:032x}", windows_core::GUID::new().ok()?.to_u128());
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
        let dir = tempfile::tempdir().unwrap();
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
        let dir = tempfile::tempdir().unwrap();
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
        for name in ["sample.exe", "sample.AppImage"] {
            let previous = tempfile::Builder::new().suffix(name).tempfile().unwrap();
            let expected = file_icon_provider::get_file_icon(previous.path(), 64).unwrap();
            let actual = icon(name, 64).unwrap();
            assert_eq!((actual.width, actual.height), (64, 64));
            assert!(
                actual.pixels == expected.pixels,
                "different icon for {name}"
            );
        }
    }
}
