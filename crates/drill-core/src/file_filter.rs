use std::ffi::OsStr;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum FileFilter {
    All,
    MacBundles,
    WindowsExecutables,
}

impl FileFilter {
    pub(super) fn accepts_extension(self, extension: &OsStr, is_dir: bool, is_file: bool) -> bool {
        match self {
            Self::All => true,
            Self::MacBundles => is_dir && extension.eq_ignore_ascii_case("app"),
            Self::WindowsExecutables => is_file && extension.eq_ignore_ascii_case("exe"),
        }
    }
}
