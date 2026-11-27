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
    #[ignore = "paired startup measurement on a Windows runner"]
    fn compare_startup_to_ordinary_walk() {
        let fixture = crate::test_directory::private_temp_dir();
        let system = fixture.path().join("System32");
        fs::create_dir(&system).unwrap();
        fs::write(fixture.path().join("report.txt"), b"").unwrap();
        fs::write(system.join("loom-editor.exe"), b"").unwrap();
        for (text, expected) in [
            ("report", Some("report.txt")),
            ("loom-editor", Some("loom-editor.exe")),
            ("loom-editor.exe", Some("loom-editor.exe")),
            ("drill-absent-9c3a.exe", None),
        ] {
            let mut base = Vec::new();
            let mut changed = Vec::new();
            for pair in 0..7 {
                for seeded in [pair % 2 == 0, pair % 2 != 0] {
                    let root = fixture.path().to_owned();
                    let seed = system.clone();
                    // Exercise real drive discovery in both paths. The fixture contains
                    // every seed, so both walks see the same files.
                    let discover = move |stop: &AtomicBool| {
                        let _ = default_roots_with_cancel(stop);
                        vec![root]
                    };
                    let cancel = token();
                    let query = SearchQuery::parse(text);
                    let started = Instant::now();
                    let collect = |next: &mut dyn FnMut() -> Result<
                        (MatchKind, Entry),
                        mpsc::TryRecvError,
                    >| {
                        let hit = poll(&mut *next);
                        let first = hit.as_ref().map(|_| started.elapsed());
                        assert_eq!(hit.as_ref().map(|(_, entry)| entry.name.as_str()), expected);
                        if hit.is_some() {
                            assert!(poll(next).is_none());
                        }
                        (first, started.elapsed())
                    };
                    let elapsed = if seeded {
                        let search = Search::start_seeded(
                            query,
                            Some((seed, ToolExtensions::from_pathext(None))),
                            discover,
                            cancel,
                            FileFilter::All,
                        );
                        collect(&mut || search.try_recv_hit())
                    } else {
                        let roots = discover(&cancel);
                        let search = Search::start_filtered(query, roots, cancel, FileFilter::All);
                        collect(&mut || search.try_recv_hit())
                    };
                    if pair > 0 {
                        if seeded {
                            changed.push(elapsed);
                        } else {
                            base.push(elapsed);
                        }
                    }
                }
            }
            let median = |samples: &[(Option<Duration>, Duration)]| {
                let (mut first, mut complete): (Vec<_>, Vec<_>) = samples.iter().copied().unzip();
                first.sort_unstable();
                complete.sort_unstable();
                ([first[2], first[3]], [complete[2], complete[3]])
            };
            eprintln!(
                "native startup {text:?}, 6 alternating pairs after warmup, middle pairs (first hit, completion): ordinary {:?}, seeded {:?}",
                median(&base),
                median(&changed)
            );
        }
    }
}
