use std::ffi::OsStr;
use std::path::Path;
#[cfg(windows)]
use std::path::{Component, PathBuf, Prefix};

#[derive(Default)]
pub(super) struct DirectoryPolicy {
    #[cfg(windows)]
    windows_installation: Option<PathBuf>,
}

impl DirectoryPolicy {
    pub(super) fn current() -> Self {
        Self {
            #[cfg(windows)]
            windows_installation: drill_windows::system_windows_directory(),
        }
    }

    // An explicit or discovered root can start below a maintenance directory.
    pub(super) fn root(&self, path: &Path) -> bool {
        self.child(path) || path.ancestors().skip(1).any(is_maintenance_directory)
    }

    // A child inherits its parent's tier. This check is needed only under ordinary parents.
    pub(super) fn child(&self, path: &Path) -> bool {
        #[cfg(windows)]
        if self
            .windows_installation
            .as_ref()
            .is_some_and(|installation| windows_path_starts_with(path, installation))
        {
            return true;
        }
        is_maintenance_directory(path)
    }
}

fn is_maintenance_directory(path: &Path) -> bool {
    let Some(name) = path.file_name() else {
        return false;
    };
    // Exact names reserved in common tooling for internals, downloads, caches, or environments.
    const TOOLING: &[&str] = &[
        ".git",
        ".hg",
        ".svn",
        "node_modules",
        "__pycache__",
        ".pytest_cache",
        ".mypy_cache",
        ".ruff_cache",
        ".gradle",
        ".venv",
    ];
    #[cfg(windows)]
    const ROOT_MAINTENANCE: &[&str] = &["$Recycle.Bin", "System Volume Information"];
    #[cfg(target_os = "macos")]
    const ROOT_MAINTENANCE: &[&str] = &[
        ".Spotlight-V100",
        ".fseventsd",
        ".DocumentRevisions-V100",
        ".Trashes",
    ];
    #[cfg(target_os = "linux")]
    const ROOT_MAINTENANCE: &[&str] = &["proc", "sys"];
    #[cfg(not(any(windows, target_os = "macos", target_os = "linux")))]
    const ROOT_MAINTENANCE: &[&str] = &[];

    TOOLING
        .iter()
        .any(|word| directory_name_matches(name, word))
        || (path
            .parent()
            .is_some_and(|parent| parent.has_root() && parent.parent().is_none())
            && ROOT_MAINTENANCE
                .iter()
                .any(|word| directory_name_matches(name, word)))
}

fn directory_name_matches(name: &OsStr, word: &str) -> bool {
    if cfg!(windows) {
        name.eq_ignore_ascii_case(OsStr::new(word))
    } else {
        name == word
    }
}

#[cfg(windows)]
pub(super) fn windows_path_starts_with(path: &Path, root: &Path) -> bool {
    let mut path = path.components();
    root.components().all(|root_component| {
        path.next()
            .is_some_and(|path_component| match (path_component, root_component) {
                (Component::Prefix(path), Component::Prefix(root)) => {
                    match (path.kind(), root.kind()) {
                        (
                            Prefix::Disk(path) | Prefix::VerbatimDisk(path),
                            Prefix::Disk(root) | Prefix::VerbatimDisk(root),
                        ) => path.eq_ignore_ascii_case(&root),
                        (
                            Prefix::UNC(path_server, path_share)
                            | Prefix::VerbatimUNC(path_server, path_share),
                            Prefix::UNC(root_server, root_share)
                            | Prefix::VerbatimUNC(root_server, root_share),
                        ) => {
                            path_server.eq_ignore_ascii_case(root_server)
                                && path_share.eq_ignore_ascii_case(root_share)
                        }
                        _ => path.as_os_str().eq_ignore_ascii_case(root.as_os_str()),
                    }
                }
                (Component::Normal(path), Component::Normal(root)) => {
                    path.eq_ignore_ascii_case(root)
                }
                (path, root) => path == root,
            })
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn exact_tooling_components_are_deferred() {
        let policy = DirectoryPolicy::default();
        for name in [
            ".git",
            ".hg",
            ".svn",
            "node_modules",
            "__pycache__",
            ".pytest_cache",
            ".mypy_cache",
            ".ruff_cache",
            ".gradle",
            ".venv",
        ] {
            let path = Path::new("work").join(name);
            assert!(policy.child(&path), "{}", path.display());
            assert!(policy.root(&path.join("nested").join("code")));
        }
        for name in [
            "build",
            "target",
            "dist",
            "vendor",
            "Windows",
            "Windows.old",
            "node_modules-backup",
            ".git-bak",
            "my__pycache__",
        ] {
            let path = Path::new("work").join(name);
            assert!(!policy.root(&path.join("nested")), "{}", path.display());
        }
    }

    #[cfg(unix)]
    #[test]
    fn non_utf8_directory_names_remain_ordinary() {
        use std::os::unix::ffi::OsStrExt;
        let policy = DirectoryPolicy::default();
        let path = Path::new(OsStr::from_bytes(b"/work/node_modules\xff"));
        assert!(!policy.root(path));
        assert!(policy.root(&path.join(".git")));
    }

    #[cfg(windows)]
    #[test]
    fn windows_installation_and_volume_maintenance_have_component_boundaries() {
        let policy = DirectoryPolicy {
            windows_installation: Some(r"D:\OS\Installed Windows".into()),
        };
        for path in [
            r"d:\os\installed WINDOWS",
            r"\\?\D:\OS\Installed Windows\System32\drivers",
            r"E:\$RECYCLE.BIN\SID",
            r"\\?\E:\System Volume Information",
            r"E:\Projects\Node_Modules\child",
        ] {
            assert!(policy.root(Path::new(path)), "{path}");
        }
        for path in [
            r"D:\OS\Installed Windows.old",
            r"C:\OS\Installed Windows",
            r"D:\Other\OS\Installed Windows",
            r"E:\Projects\System Volume Information",
            r"E:\Projects\$Recycle.Bin",
        ] {
            assert!(!policy.root(Path::new(path)), "{path}");
        }
    }

    #[cfg(target_os = "macos")]
    #[test]
    fn only_root_level_macos_maintenance_paths_are_deferred() {
        let policy = DirectoryPolicy::default();
        assert!(policy.root(Path::new("/.Spotlight-V100/Store-V2")));
        assert!(policy.root(Path::new("/.fseventsd")));
        assert!(!policy.root(Path::new("/work/.Spotlight-V100")));
        assert!(!policy.root(Path::new("/Applications")));
    }

    #[cfg(target_os = "linux")]
    #[test]
    fn only_root_level_kernel_filesystems_are_deferred() {
        let policy = DirectoryPolicy::default();
        assert!(policy.root(Path::new("/sys/devices")));
        assert!(policy.root(Path::new("/proc/1")));
        assert!(!policy.root(Path::new("/work/sys/devices")));
    }
}
