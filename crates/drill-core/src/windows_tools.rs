#[cfg(any(windows, test))]
use std::ffi::OsStr;
use std::{fs, path::Path};

const BUILTIN_EXTENSIONS: &[&[u8]] = &[b"EXE", b"COM", b"BAT", b"CMD", b"MSC", b"CPL"];

// Remaining entries from the Windows command prompt's default PATHEXT.
const FALLBACK_EXTENSIONS: &[&[u8]] = &[b"VBS", b"VBE", b"JS", b"JSE", b"WSF", b"WSH"];

pub(super) struct ToolExtensions {
    configured: Vec<Vec<u8>>,
}

impl ToolExtensions {
    #[cfg(windows)]
    pub(super) fn from_environment() -> Self {
        Self::from_pathext(std::env::var_os("PATHEXT").as_deref())
    }

    #[cfg(any(windows, test))]
    pub(super) fn from_pathext(pathext: Option<&OsStr>) -> Self {
        let configured = pathext
            .unwrap_or_default()
            .as_encoded_bytes()
            .split(|&byte| byte == b';')
            .filter_map(|value| value.trim_ascii().strip_prefix(b"."))
            .filter(|extension| {
                !extension.is_empty()
                    && extension
                        .iter()
                        .all(|byte| !byte.is_ascii_control() && !b".<>:\"/\\|?*".contains(byte))
            })
            .map(<[u8]>::to_vec)
            .collect();
        Self { configured }
    }

    pub(super) fn matches(&self, path: &Path, file_type: fs::FileType) -> bool {
        if !file_type.is_file() {
            return false;
        }
        let Some(extension) = path.extension() else {
            return false;
        };
        let extension = extension.as_encoded_bytes();
        let matches = |candidate: &[u8]| extension.eq_ignore_ascii_case(candidate);
        BUILTIN_EXTENSIONS.iter().copied().any(matches)
            || if self.configured.is_empty() {
                FALLBACK_EXTENSIONS.iter().copied().any(matches)
            } else {
                self.configured.iter().map(Vec::as_slice).any(matches)
            }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn file_type() -> fs::FileType {
        fs::metadata(std::env::current_exe().unwrap())
            .unwrap()
            .file_type()
    }

    #[test]
    fn missing_or_unusable_pathext_uses_windows_defaults() {
        let file_type = file_type();
        for pathext in [
            None,
            Some(OsStr::new("")),
            Some(OsStr::new(" ; .;DLL;.*;./TXT")),
        ] {
            let tools = ToolExtensions::from_pathext(pathext);
            for name in [
                "tool.eXe", "tool.coM", "tool.Bat", "tool.CmD", "tool.VbS", "tool.mSc", "tool.cpL",
            ] {
                assert!(tools.matches(Path::new(name), file_type), "{name}");
            }
            for name in ["tool", "tool.dll", "notes.txt", "tool.exe.dll"] {
                assert!(!tools.matches(Path::new(name), file_type), "{name}");
            }
        }
    }

    #[test]
    fn configured_extensions_are_literal_and_keep_builtin_tools() {
        let file_type = file_type();
        let tools = ToolExtensions::from_pathext(Some(OsStr::new(
            " .Py ; .TOOL-2;pyw;*.txt;.t?t;.foo.bar;.x/y;.x\\y",
        )));
        for name in [
            "tool.pY",
            "tool.tool-2",
            "tool.ExE",
            "tool.cmd",
            "tool.msc",
            "tool.cpl",
        ] {
            assert!(tools.matches(Path::new(name), file_type), "{name}");
        }
        for name in ["tool.js", "tool.pyw", "tool.txt", "tool.bar", "tool.y"] {
            assert!(!tools.matches(Path::new(name), file_type), "{name}");
        }
    }

    #[test]
    fn a_directory_named_like_a_tool_does_not_match() {
        let temp = crate::test_directory::private_temp_dir();
        let directory = temp.path().join("folder.exe");
        fs::create_dir(&directory).unwrap();
        let tools = ToolExtensions::from_pathext(None);
        assert!(!tools.matches(&directory, fs::metadata(&directory).unwrap().file_type()));
    }

    #[cfg(any(unix, windows))]
    #[test]
    fn a_tool_can_have_a_non_unicode_stem() {
        #[cfg(unix)]
        let name: std::ffi::OsString = {
            use std::os::unix::ffi::OsStrExt;

            OsStr::from_bytes(b"tool\xff.exe").to_owned()
        };
        #[cfg(windows)]
        let name = {
            use std::os::windows::ffi::OsStringExt;

            std::ffi::OsString::from_wide(&[0xd800, 0x2e, 0x65, 0x78, 0x65])
        };
        let tools = ToolExtensions::from_pathext(None);
        assert!(tools.matches(Path::new(&name), file_type()));
    }
}
