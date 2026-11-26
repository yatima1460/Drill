use super::*;

impl Search {
    /// Delivers exact system executables before discovering optional drives and game libraries.
    #[cfg(windows)]
    pub fn start_windows_default(
        query: SearchQuery,
        cancel: Arc<AtomicBool>,
        filter: FileFilter,
        on_exact: impl FnMut(Entry),
    ) -> Self {
        let windows = std::env::var_os("SystemRoot").map(PathBuf::from);
        let apps = std::env::var_os("LOCALAPPDATA").map(PathBuf::from);
        let dirs = windows
            .filter(|root| root.is_absolute())
            .into_iter()
            .flat_map(|root| [root.join("System32"), root])
            .chain(
                apps.filter(|root| root.is_absolute())
                    .map(|root| root.join("Microsoft/WindowsApps")),
            );
        Self::start_with_system_dirs(
            query,
            cancel,
            filter,
            dirs,
            default_roots_with_cancel,
            on_exact,
        )
    }

    fn start_with_system_dirs(
        query: SearchQuery,
        cancel: Arc<AtomicBool>,
        filter: FileFilter,
        dirs: impl IntoIterator<Item = PathBuf>,
        discover: impl FnOnce(&AtomicBool) -> Vec<PathBuf>,
        mut on_exact: impl FnMut(Entry),
    ) -> Self {
        let mut delivered = HashSet::new();
        if query.is_plain_executable_name() && filter != FileFilter::MacBundles {
            for dir in dirs {
                if cancel.load(Ordering::Relaxed) {
                    break;
                }
                let Ok(entries) = fs::read_dir(dir) else {
                    continue;
                };
                for item in entries.flatten() {
                    if cancel.load(Ordering::Relaxed) {
                        break;
                    }
                    let name = item.file_name().to_string_lossy().into_owned();
                    if query.classify(&name) != Some(MatchKind::Exact) {
                        continue;
                    }
                    let path = item.path();
                    let Ok(metadata) = item.metadata() else {
                        continue;
                    };
                    if !metadata.is_file() || !filter.accepts(&path, metadata.file_type()) {
                        continue;
                    }
                    if entry_key(&path).is_some_and(|key| delivered.insert(key)) {
                        on_exact(Entry {
                            path,
                            name,
                            size: Some(metadata.len()),
                            modified: metadata.modified().ok(),
                            is_dir: false,
                        });
                    }
                    // A single result per directory keeps the startup stream bounded.
                    break;
                }
            }
        }
        let roots = if cancel.load(Ordering::Relaxed) {
            Vec::new()
        } else {
            discover(&cancel)
        };
        Self::start_remaining(query, roots, cancel, filter, delivered)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::cell::RefCell;
    use std::time::Duration;

    #[test]
    fn exact_tools_arrive_before_root_discovery_and_only_once() {
        let temp = tempfile::tempdir().unwrap();
        let system = temp.path().join("System32");
        let other = temp.path().join("other");
        fs::create_dir(&system).unwrap();
        fs::create_dir(&other).unwrap();
        let expected = system.join("Demo Tool.EXE");
        fs::write(&expected, b"fixture").unwrap();
        fs::write(other.join("demo tool.exe"), b"other").unwrap();
        fs::write(system.join("Demo Tool.EXE.bak"), b"backup").unwrap();
        let early = RefCell::new(Vec::new());
        let scan = Search::start_with_system_dirs(
            SearchQuery::parse("demo tool.exe"),
            Arc::new(AtomicBool::new(false)),
            FileFilter::All,
            [system.clone(), system.clone()],
            |_| {
                // Verify the exact row is available while broad discovery is still pending.
                assert_eq!(&*early.borrow(), &[(expected.clone(), Some(7))]);
                vec![temp.path().into(), system.clone()]
            },
            |entry| early.borrow_mut().push((entry.path, entry.size)),
        );
        let mut late = Vec::new();
        loop {
            match scan.receiver.recv_timeout(Duration::from_secs(5)) {
                Ok((rank, entry)) => late.push((entry.name, rank)),
                Err(mpsc::RecvTimeoutError::Disconnected) => break,
                Err(mpsc::RecvTimeoutError::Timeout) => panic!("scan stalled"),
            }
        }
        late.sort_by(|a, b| a.0.cmp(&b.0));
        assert_eq!(
            late,
            [
                ("Demo Tool.EXE.bak".into(), MatchKind::Partial),
                ("demo tool.exe".into(), MatchKind::Exact),
            ]
        );
    }

    #[test]
    fn only_plain_executable_names_use_the_preview() {
        for text in [
            "notepad",
            "regex:notepad.exe",
            "*.exe",
            "fuzzy:notepad.exe",
            r"sub\notepad.exe",
        ] {
            assert!(
                !SearchQuery::parse(text).is_plain_executable_name(),
                "{text}"
            );
        }
        assert!(SearchQuery::parse("NOTEPAD.EXE").is_plain_executable_name());
    }

    #[cfg(windows)]
    #[test]
    #[ignore = "requires the host to have the Windows Notepad executable installed"]
    fn default_windows_search_finds_installed_notepad_before_drive_discovery() {
        let root = PathBuf::from(std::env::var_os("SystemRoot").unwrap());
        let expected = [root.join("System32/notepad.exe"), root.join("notepad.exe")];
        assert!(
            expected.iter().any(|p| p.is_file()),
            "fixture host needs the Windows Notepad executable"
        );
        for filter in [FileFilter::All, FileFilter::WindowsExecutables] {
            let cancel = Arc::new(AtomicBool::new(false));
            let mut found = false;
            let started = std::time::Instant::now();
            let scan = Search::start_windows_default(
                SearchQuery::parse("notepad.exe"),
                cancel.clone(),
                filter,
                |entry| {
                    let actual = fs::canonicalize(&entry.path).unwrap();
                    assert!(expected
                        .iter()
                        .filter_map(|p| fs::canonicalize(p).ok())
                        .any(|p| p == actual));
                    eprintln!(
                        "first Notepad hit in {:?}: {}",
                        started.elapsed(),
                        entry.path.display()
                    );
                    found = true;
                    cancel.store(true, Ordering::Relaxed);
                },
            );
            assert!(found && scan.done());
        }
    }
}
