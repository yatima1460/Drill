use super::*;

/// Streams matching tools directly inside System32 during default root discovery.
#[cfg(windows)]
pub struct WindowsSearch {
    walk: Search,
}

#[cfg(windows)]
impl WindowsSearch {
    pub fn start(query: SearchQuery, cancel: Arc<AtomicBool>, filter: FileFilter) -> Self {
        let seed = (!cancel.load(Ordering::Relaxed)
            && query.error().is_none()
            && filter != FileFilter::MacBundles)
            .then(drill_windows::system_windows_directory)
            .flatten()
            .map(|windows| (windows.join("System32"), ToolExtensions::from_environment()));
        let walk = Search::start_seeded(query, seed, default_roots_with_cancel, cancel, filter);
        Self { walk }
    }

    pub fn try_recv_hit(&mut self) -> Result<(MatchKind, Entry), mpsc::TryRecvError> {
        self.walk.try_recv_hit()
    }

    pub fn set_paused(&mut self, paused: bool) {
        self.walk.set_paused(paused);
    }

    pub fn pending(&self) -> Option<usize> {
        Some(self.walk.pending())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::{Duration, Instant};

    const TIMEOUT: Duration = Duration::from_secs(10);
    fn token() -> Arc<AtomicBool> {
        Arc::new(AtomicBool::new(false))
    }
    fn poll<T>(mut f: impl FnMut() -> Result<T, mpsc::TryRecvError>) -> Option<T> {
        let deadline = Instant::now() + TIMEOUT;
        loop {
            match f() {
                Ok(hit) => return Some(hit),
                Err(mpsc::TryRecvError::Disconnected) => return None,
                Err(mpsc::TryRecvError::Empty) => {
                    assert!(Instant::now() < deadline, "search stalled");
                    thread::yield_now();
                }
            }
        }
    }

    #[test]
    fn only_shallow_system_tools_stream_before_discovery() {
        let temp = crate::test_directory::private_temp_dir();
        let drive = fs::canonicalize(temp.path()).unwrap();
        let windows = drive.join("Windows");
        let system = windows.join("System32");
        let folder = system.join("loom-folder.exe");
        fs::create_dir_all(&folder).unwrap();
        let tool = system.join("loom.exe");
        let root_tool = windows.join("loom-helper.EXE");
        let command = system.join("loom-setup.cmd");
        let nested = folder.join("loom-nested.exe");
        let dll = system.join("loom-library.dll");
        let readme = system.join("loom-readme.txt");
        let ordinary = drive.join("loom-document.txt");
        for path in [
            &tool, &root_tool, &command, &nested, &dll, &readme, &ordinary,
        ] {
            fs::write(path, b"").unwrap();
        }
        for (filter, rank) in [
            (FileFilter::All, MatchKind::Partial),
            (FileFilter::WindowsExecutables, MatchKind::Exact),
        ] {
            let (release, gate) = mpsc::channel();
            let (entered, discovery_started) = mpsc::channel();
            let drive = drive.clone();
            let system = system.clone();
            let windows = windows.clone();
            let scan = Search::start_seeded(
                SearchQuery::parse("loom"),
                Some((system.clone(), ToolExtensions::from_pathext(None))),
                move |_| {
                    entered.send(()).unwrap();
                    gate.recv_timeout(TIMEOUT).unwrap();
                    vec![drive, windows, system]
                },
                token(),
                filter,
            );
            discovery_started.recv_timeout(TIMEOUT).unwrap();
            let mut early = HashSet::new();
            for _ in 0..2 {
                let (kind, hit) = poll(|| scan.try_recv_hit()).unwrap();
                let expected_rank = if hit.path == tool {
                    rank
                } else {
                    MatchKind::Partial
                };
                assert_eq!(kind, expected_rank);
                assert!(early.insert(hit.path));
            }
            assert_eq!(early, [tool.clone(), command.clone()].into());
            assert!(matches!(
                scan.try_recv_hit(),
                Err(mpsc::TryRecvError::Empty)
            ));

            release.send(()).unwrap();
            let mut remaining = HashSet::new();
            while let Some((_, hit)) = poll(|| scan.try_recv_hit()) {
                assert!(remaining.insert(hit.path));
            }
            let mut expected = HashSet::from([nested.clone(), root_tool.clone()]);
            if filter == FileFilter::All {
                expected.extend([
                    dll.clone(),
                    readme.clone(),
                    ordinary.clone(),
                    folder.clone(),
                ]);
            }
            assert_eq!(remaining, expected);
            assert_eq!(scan.pending(), 0);
        }
    }

    #[test]
    fn literal_and_glob_queries_use_the_same_shallow_walk() {
        let fixture = crate::test_directory::private_temp_dir();
        let root = fs::canonicalize(fixture.path()).unwrap();
        let system = root.join("System32");
        let windows_apps = root.join("Microsoft/WindowsApps");
        for directory in [&system, &windows_apps] {
            fs::create_dir_all(directory).unwrap();
            fs::write(directory.join("CaféTool.EXE"), b"").unwrap();
        }
        fs::write(root.join("CaféTool.EXE"), b"").unwrap();
        let expected = system.join("CaféTool.EXE");
        for query in ["CaféTool.EXE", "glob:*.EXE"] {
            let (release, gate) = mpsc::channel();
            let root = root.clone();
            let scan = Search::start_seeded(
                SearchQuery::parse(query),
                Some((system.clone(), ToolExtensions::from_pathext(None))),
                move |_| {
                    gate.recv_timeout(TIMEOUT).unwrap();
                    vec![root]
                },
                token(),
                FileFilter::All,
            );
            let (_, hit) = poll(|| scan.try_recv_hit()).unwrap();
            assert_eq!(hit.path, expected);
            assert!(matches!(
                scan.try_recv_hit(),
                Err(mpsc::TryRecvError::Empty)
            ));
            release.send(()).unwrap();
            let mut matches = HashSet::new();
            while let Some((_, hit)) = poll(|| scan.try_recv_hit()) {
                assert!(matches.insert(hit.path));
            }
            assert_eq!(
                matches,
                [
                    fixture.path().join("CaféTool.EXE"),
                    windows_apps.join("CaféTool.EXE")
                ]
                .into_iter()
                .map(|path| fs::canonicalize(path).unwrap())
                .collect(),
            );
        }
    }

    #[test]
    fn more_matches_than_the_channel_capacity_can_stream_during_discovery() {
        let fixture = crate::test_directory::private_temp_dir();
        let system = fs::canonicalize(fixture.path()).unwrap();
        let expected: HashSet<_> = (0..520)
            .map(|index| {
                let path = system.join(format!("cobalt-{index}.exe"));
                fs::write(&path, []).unwrap();
                path
            })
            .collect();
        let (release, gate) = mpsc::channel();
        let scan = Search::start_seeded(
            SearchQuery::parse("cobalt"),
            Some((system.clone(), ToolExtensions::from_pathext(None))),
            move |_| {
                gate.recv_timeout(TIMEOUT).unwrap();
                vec![system]
            },
            token(),
            FileFilter::All,
        );
        let matches = (0..expected.len())
            .map(|_| poll(|| scan.try_recv_hit()).unwrap().1.path)
            .collect();
        assert_eq!(expected, matches);
        release.send(()).unwrap();
        assert!(poll(|| scan.try_recv_hit()).is_none());
    }

    #[cfg(windows)]
    #[test]
    #[ignore = "requires an installed Windows Notepad"]
    fn installed_notepad_in_both_modes() {
        let expected = drill_windows::system_windows_directory()
            .unwrap()
            .join("System32")
            .join("notepad.exe");
        let expected = fs::canonicalize(expected).unwrap();
        for filter in [FileFilter::All, FileFilter::WindowsExecutables] {
            for text in ["notepad", "NOTEPAD.EXE"] {
                let start = Instant::now();
                let mut scan = WindowsSearch::start(SearchQuery::parse(text), token(), filter);
                loop {
                    assert!(
                        start.elapsed() < TIMEOUT,
                        "{text} in {filter:?} took too long"
                    );
                    let Some((rank, hit)) = poll(|| scan.try_recv_hit()) else {
                        panic!("missing installed Notepad for {text} in {filter:?}");
                    };
                    if !hit.name.eq_ignore_ascii_case("notepad.exe")
                        || fs::canonicalize(&hit.path).ok().as_ref() != Some(&expected)
                    {
                        continue;
                    }
                    let expected_rank = if text == "notepad" && filter == FileFilter::All {
                        MatchKind::Partial
                    } else {
                        MatchKind::Exact
                    };
                    assert_eq!(rank, expected_rank);
                    eprintln!(
                        "{filter:?} {text} found {} in {:?}",
                        hit.path.display(),
                        start.elapsed()
                    );
                    break;
                }
            }
        }
    }

    #[cfg(windows)]
    #[test]
    #[ignore = "paired startup measurement on a Windows runner"]
    fn compare_startup_to_ordinary_walk() {
        use std::os::windows::fs::MetadataExt;

        let fixture = crate::test_directory::private_temp_dir();
        let root = fs::canonicalize(fixture.path()).unwrap();
        let system = root.join("System32");
        fs::create_dir(&system).unwrap();
        let installed = drill_windows::system_windows_directory()
            .expect("Windows directory unavailable")
            .join("System32");
        let extensions = ToolExtensions::from_environment();
        let (mut files, mut directories, mut tools, mut skipped) = (0, 0, 0, 0);
        for entry in fs::read_dir(installed).unwrap() {
            let Ok(entry) = entry else {
                skipped += 1;
                continue;
            };
            let Ok(metadata) = entry.metadata() else {
                skipped += 1;
                continue;
            };
            const FILE_ATTRIBUTE_REPARSE_POINT: u32 = 0x400;
            let kind = metadata.file_type();
            let path = system.join(entry.file_name());
            // Mirror names only. Reparse points could point outside the snapshot.
            if metadata.file_attributes() & FILE_ATTRIBUTE_REPARSE_POINT != 0 {
                skipped += 1;
            } else if kind.is_file() {
                fs::File::create_new(&path).unwrap();
                files += 1;
                tools += usize::from(extensions.matches(&path, kind));
            } else if kind.is_dir() {
                fs::create_dir(&path).unwrap();
                directories += 1;
            } else {
                skipped += 1;
            }
        }
        assert!(files > 0, "System32 provided no regular files");

        // The private fixture name includes a random suffix to avoid matching a mirrored name.
        let prefix = fixture.path().file_name().unwrap().to_str().unwrap();
        let report = root.join(format!("{prefix}-report.txt"));
        let tool_stem = format!("{prefix}-tool");
        let tool_name = format!("{tool_stem}.exe");
        let tool = system.join(&tool_name);
        let absent = format!("{prefix}-absent.exe");
        fs::File::create_new(&report).unwrap();
        fs::File::create_new(&tool).unwrap();

        const PAIRS: usize = 6;
        eprintln!(
            "System32 top-level names snapshot with {files} empty files ({tools} launchable), \
             {directories} empty directories and {skipped} skipped entries, plus 2 sentinel files. \
             Debug assertions {}, warm filesystem, 1 warmup pair per query then {PAIRS} alternating pairs. \
             Timed from before discovery to first hit and stream drain. Fixture creation and build excluded.",
            cfg!(debug_assertions),
        );
        for (text, expected) in [
            (report.file_name().unwrap().to_str().unwrap(), Some(&report)),
            (tool_stem.as_str(), Some(&tool)),
            (tool_name.as_str(), Some(&tool)),
            (absent.as_str(), None),
        ] {
            let mut base = Vec::new();
            let mut changed = Vec::new();
            let mut threads = [0; 2];
            for pair in 0..=PAIRS {
                for seeded in [pair % 2 == 0, pair % 2 != 0] {
                    let root = root.clone();
                    let seed = system.clone();
                    // Run the usual drive discovery in both paths, then walk the same bounded tree.
                    let discover = move |stop: &AtomicBool| {
                        let _ = default_roots_with_cancel(stop);
                        vec![root]
                    };
                    let cancel = token();
                    let query = SearchQuery::parse(text);
                    let started = Instant::now();
                    let search = if seeded {
                        Search::start_seeded(
                            query,
                            Some((seed, ToolExtensions::from_environment())),
                            discover,
                            cancel,
                            FileFilter::All,
                        )
                    } else {
                        let roots = discover(&cancel);
                        Search::start_filtered(query, roots, cancel, FileFilter::All)
                    };
                    threads[usize::from(seeded)] = search.workers.len() - usize::from(seeded);
                    let hit = poll(|| search.try_recv_hit());
                    let first = hit.as_ref().map(|_| started.elapsed());
                    let repeated = hit.is_some() && poll(|| search.try_recv_hit()).is_some();
                    let complete = started.elapsed();
                    assert_eq!(hit.as_ref().map(|(_, entry)| &entry.path), expected);
                    assert!(!repeated, "search returned another match");
                    if pair > 0 {
                        if seeded {
                            changed.push((first, complete));
                        } else {
                            base.push((first, complete));
                        }
                    }
                }
            }
            let medians = |samples: &[(Option<Duration>, Duration)]| {
                let (mut first, mut complete): (Vec<_>, Vec<_>) = samples.iter().copied().unzip();
                first.sort_unstable();
                complete.sort_unstable();
                let middle = PAIRS / 2;
                let first = first[middle - 1]
                    .zip(first[middle])
                    .map(|(left, right)| (left + right) / 2);
                (first, (complete[middle - 1] + complete[middle]) / 2)
            };
            eprintln!(
                "{text:?} median (first hit, full drain): ordinary {:?} with {} walk workers, \
                 seeded {:?} with {} walk workers and 1 discovery worker",
                medians(&base),
                threads[0],
                medians(&changed),
                threads[1],
            );
        }
    }
}
