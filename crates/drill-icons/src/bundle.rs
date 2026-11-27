//! Read the icon named by one application bundle, through verified directory handles.
use std::ffi::OsStr;
use std::fs::File;
use std::io::Read;
use std::path::Path;

#[cfg(target_os = "linux")]
#[path = "bundle_linux.rs"]
mod platform;
#[cfg(target_os = "macos")]
#[path = "bundle_macos.rs"]
mod platform;
#[cfg(windows)]
#[path = "bundle_windows.rs"]
mod platform;
#[path = "bundle_plist.rs"]
mod plist;

const MAX_PLIST: usize = 256 * 1024;
const MAX_ICON: usize = 16 * 1024 * 1024;

pub(super) fn snapshot(path: &Path, is_current: &impl Fn() -> bool) -> Option<Vec<u8>> {
    if !is_current()
        || !path.extension()?.eq_ignore_ascii_case("app")
        || path.as_os_str().as_encoded_bytes().len() > 32_767
        || path.components().count() > 128
    {
        return None;
    }
    #[cfg(target_os = "macos")]
    let _policy = crate::macos::MaterializationPolicy::disable()?;
    let contents = platform::contents(path, is_current)?;
    let info = platform::child(&contents, OsStr::new("Info.plist"), false)?;
    let info = read_bounded(info, MAX_PLIST, is_current)?;
    let name = plist::icon_file(&info).unwrap_or_else(|| "AppIcon".to_owned());
    let name = resource_name(name)?;
    if !is_current() {
        return None;
    }
    let resources = platform::child(&contents, OsStr::new("Resources"), true)?;
    let icon = platform::child(&resources, OsStr::new(&name), false)?;
    read_bounded(icon, MAX_ICON, is_current)
}

fn read_bounded(mut file: File, limit: usize, is_current: &impl Fn() -> bool) -> Option<Vec<u8>> {
    let length = usize::try_from(file.metadata().ok()?.len()).ok()?;
    if length == 0 || length > limit || !is_current() {
        return None;
    }

    let mut bytes = vec![0; length];
    for chunk in bytes.chunks_mut(32 * 1024) {
        if !is_current() {
            return None;
        }
        file.read_exact(chunk).ok()?;
    }
    // A file may have grown since the size check. Never copy the excess.
    (is_current() && file.read(&mut [0]).ok()? == 0).then_some(bytes)
}

fn resource_name(mut name: String) -> Option<String> {
    if !safe_name(&name) {
        return None;
    }
    if !Path::new(&name)
        .extension()
        .is_some_and(|ext| ext.eq_ignore_ascii_case("icns"))
    {
        name.push_str(".icns");
    }
    (name.len() <= 255).then_some(name)
}

// Validate the plist's filename using the same rules on each platform. The
// Win32 aliases are reserved even with an extension (including superscript digits).
fn safe_name(name: &str) -> bool {
    if name.is_empty()
        || name.len() > 255
        || name.ends_with(['.', ' '])
        || name
            .chars()
            .any(|c| c.is_control() || r#"<>:"/\|?*"#.contains(c))
    {
        return false;
    }
    let stem = name
        .split('.')
        .next()
        .unwrap_or("")
        .trim_end_matches(' ')
        .to_ascii_uppercase();
    if matches!(
        stem.as_str(),
        "CON" | "PRN" | "AUX" | "NUL" | "CONIN$" | "CONOUT$" | "CLOCK$"
    ) {
        return false;
    }
    let port = stem
        .strip_prefix("COM")
        .or_else(|| stem.strip_prefix("LPT"));
    !port.is_some_and(|suffix| {
        suffix.len() == 1 && suffix.as_bytes()[0].is_ascii_digit()
            || matches!(suffix, "¹" | "²" | "³")
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::cell::Cell;
    use std::fs;

    const DECLARED: &str =
        "<plist><dict><key>CFBundleIconFile</key><string>Named</string></dict></plist>";

    fn fixture() -> (crate::test_directory::TestDirectory, std::path::PathBuf) {
        let temp = crate::test_directory::private_temp_dir();
        // macOS places its temporary directory under the /var symlink.
        let app = temp.path().canonicalize().unwrap().join("Example.app");
        let contents = app.join("Contents");
        fs::create_dir_all(contents.join("Resources")).unwrap();
        fs::write(contents.join("Info.plist"), DECLARED).unwrap();
        (temp, app)
    }

    #[test]
    fn reads_the_declared_resource_and_conventional_fallback() {
        let (_temp, app) = fixture();
        let contents = app.join("Contents");
        fs::write(contents.join("Resources/Named.icns"), b"named").unwrap();
        fs::write(contents.join("Resources/AppIcon.icns"), b"default").unwrap();
        assert_eq!(snapshot(&app, &|| true).as_deref(), Some(&b"named"[..]));
        fs::write(contents.join("Info.plist"), "<plist><dict/></plist>").unwrap();
        assert_eq!(snapshot(&app, &|| true).as_deref(), Some(&b"default"[..]));
    }

    #[test]
    fn rejects_unsafe_names_and_accepts_one_icns_filename() {
        for name in [
            "",
            ".",
            "..",
            "../icon",
            r"..\icon",
            r"C:\icon",
            "//server/x",
            "data:stream",
            "NUL.icns",
            "Con .icns",
            "LPT².icns",
            "com1",
            "app. ",
            "a\0b",
            "bad*",
        ] {
            assert_eq!(resource_name(name.to_owned()), None, "{name:?}");
        }
        assert_eq!(
            resource_name("paint.v2".to_owned()).as_deref(),
            Some("paint.v2.icns")
        );
        assert_eq!(
            resource_name("Icon.ICNS".to_owned()).as_deref(),
            Some("Icon.ICNS")
        );
        assert!(resource_name("a".repeat(251)).is_none());
    }

    #[test]
    fn skips_missing_oversize_and_cancelled_reads() {
        let (_temp, app) = fixture();
        assert!(snapshot(&app, &|| true).is_none());
        let path = app.join("Contents/Resources/Named.icns");
        let file = File::create_new(&path).unwrap();
        file.set_len(MAX_ICON as u64 + 1).unwrap();
        assert!(snapshot(&app, &|| true).is_none());
        file.set_len(128 * 1024).unwrap();
        let calls = Cell::new(0);
        assert!(read_bounded(File::open(&path).unwrap(), MAX_ICON, &|| {
            calls.set(calls.get() + 1);
            calls.get() < 3
        })
        .is_none());
        assert_eq!(calls.get(), 3);
        assert!(snapshot(&app, &|| false).is_none());
        File::options()
            .write(true)
            .open(app.join("Contents/Info.plist"))
            .unwrap()
            .set_len(MAX_PLIST as u64 + 1)
            .unwrap();
        assert!(snapshot(&app, &|| true).is_none());
    }

    #[cfg(unix)]
    #[test]
    #[allow(unsafe_code)]
    fn rejects_named_pipes_and_keeps_the_open_directory_after_a_rename() {
        use std::os::unix::ffi::OsStrExt;
        let (temp, app) = fixture();
        let original = platform::contents(&app, &|| true).unwrap();
        let icon = app.join("Contents/Resources/Named.icns");
        let path = std::ffi::CString::new(icon.as_os_str().as_bytes()).unwrap();
        // SAFETY: mkfifo receives a valid, terminated path inside the private fixture.
        assert_eq!(unsafe { libc::mkfifo(path.as_ptr(), 0o600) }, 0);
        assert!(snapshot(&app, &|| true).is_none());

        fs::rename(app.join("Contents"), temp.path().join("original")).unwrap();
        fs::create_dir(app.join("Contents")).unwrap();
        fs::write(app.join("Contents/Info.plist"), "replacement").unwrap();
        let file = platform::child(&original, OsStr::new("Info.plist"), false).unwrap();
        assert_eq!(
            read_bounded(file, MAX_PLIST, &|| true).unwrap(),
            DECLARED.as_bytes()
        );
    }

    #[cfg(unix)]
    #[test]
    fn skips_symlinks_at_every_bundle_boundary() {
        use std::os::unix::fs::symlink;
        let (temp, app) = fixture();
        let contents = app.join("Contents");
        let icon = contents.join("Resources/Named.icns");
        fs::write(&icon, b"icon").unwrap();
        for path in [
            &icon,
            &contents.join("Info.plist"),
            &contents.join("Resources"),
            &contents,
            &app,
        ] {
            let moved = temp.path().join("moved");
            fs::rename(path, &moved).unwrap();
            symlink(&moved, path).unwrap();
            assert!(snapshot(&app, &|| true).is_none(), "{path:?}");
            fs::remove_file(path).unwrap();
            fs::rename(&moved, path).unwrap();
        }
    }
}
