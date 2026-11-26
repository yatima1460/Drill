use super::*;
use std::sync::atomic::AtomicUsize;

struct Permit(Arc<AtomicUsize>);
impl Permit {
    fn acquire(active: Arc<AtomicUsize>) -> Option<Self> {
        active
            .try_update(Ordering::Relaxed, Ordering::Relaxed, |n| {
                (n < 2).then_some(n + 1)
            })
            .ok()?;
        Some(Self(active))
    }
}
impl Drop for Permit {
    fn drop(&mut self) {
        self.0.fetch_sub(1, Ordering::Relaxed);
    }
}

#[cfg(windows)]
fn system_dirs() -> Vec<PathBuf> {
    let root = std::env::var_os("SystemRoot").map(PathBuf::from);
    let apps = std::env::var_os("LOCALAPPDATA").map(PathBuf::from);
    root.filter(|p| p.is_absolute())
        .into_iter()
        .flat_map(|p| [p.join("System32"), p])
        .chain(
            apps.filter(|p| p.is_absolute())
                .map(|p| p.join("Microsoft/WindowsApps")),
        )
        .collect()
}

// The path argument always contains exactly one validated filename below a known directory.
// Query the file directly: an absent executable costs one lookup per directory.
fn lookup(path: &Path, filter: FileFilter) -> Option<(PathBuf, Entry)> {
    #[cfg(windows)]
    let name = {
        let mut data = winsafe::WIN32_FIND_DATA::default();
        let (_handle, found) = winsafe::HFINDFILE::FindFirstFile(path.to_str()?, &mut data).ok()?;
        if !found {
            return None;
        }
        data.cFileName()
    };
    #[cfg(not(windows))]
    let name = path.file_name()?.to_str()?.to_owned();
    // A short (8.3) alias may resolve to an unrelated long name.
    if !drill_query::equivalent_filenames(&name, path.file_name()?.to_str()?) {
        return None;
    }
    let actual_path = path.with_file_name(&name);
    let metadata = fs::symlink_metadata(&actual_path).ok()?;
    if !metadata.is_file() || !filter.accepts(&actual_path, metadata.file_type()) {
        return None;
    }
    Some((
        entry_key(&actual_path)?,
        Entry {
            path: actual_path,
            name,
            size: Some(metadata.len()),
            modified: metadata.modified().ok(),
            is_dir: false,
        },
    ))
}

/// Merges the ordinary search with an optional bounded set of direct system lookups.
pub struct WindowsSearch {
    starting: Option<mpsc::Receiver<Search>>,
    walk: Option<Search>,
    preview: Option<mpsc::Receiver<Entry>>,
    cancel: Arc<AtomicBool>,
    paused: bool,
}
impl WindowsSearch {
    #[cfg(windows)]
    pub fn start(query: SearchQuery, cancel: Arc<AtomicBool>, filter: FileFilter) -> Self {
        static ACTIVE: OnceLock<Arc<AtomicUsize>> = OnceLock::new();
        Self::start_with(
            query,
            cancel,
            filter,
            default_roots_with_cancel,
            || Permit::acquire(ACTIVE.get_or_init(Default::default).clone()),
            system_dirs,
            lookup,
        )
    }

    fn start_with(
        query: SearchQuery,
        cancel: Arc<AtomicBool>,
        filter: FileFilter,
        discover: impl FnOnce(&AtomicBool) -> Vec<PathBuf> + Send + 'static,
        permit: impl FnOnce() -> Option<Permit>,
        dirs: impl FnOnce() -> Vec<PathBuf> + Send + 'static,
        lookup: impl Fn(&Path, FileFilter) -> Option<(PathBuf, Entry)> + Send + 'static,
    ) -> Self {
        let eligible = !cancel.load(Ordering::Relaxed) && filter != FileFilter::MacBundles;
        let probe = query
            .executable_filename()
            .filter(|_| eligible)
            .and_then(|name| Some((name.to_owned(), permit()?)));
        let mut search = Self {
            starting: None,
            walk: None,
            preview: None,
            cancel: cancel.clone(),
            paused: false,
        };
        let Some((filename, permit)) = probe else {
            let roots = discover(&cancel);
            search.walk = Some(Search::start_filtered(query, roots, cancel, filter));
            return search;
        };
        let paths = Arc::new(Mutex::new(PreviewPaths::default()));
        let (ready, starting) = mpsc::channel();
        let walk_cancel = cancel.clone();
        let walk_paths = paths.clone();
        thread::spawn(move || {
            let roots = discover(&walk_cancel);
            let walk = Search::start_remaining(query, roots, walk_cancel, filter, Some(walk_paths));
            let _ = ready.send(walk);
        });
        let (send, receive) = mpsc::channel();
        thread::spawn(move || {
            let _permit = permit;
            for dir in dirs() {
                if cancel.load(Ordering::Relaxed) || paths.lock().unwrap().finished {
                    break;
                }
                let Some((key, entry)) = lookup(&dir.join(&filename), filter) else {
                    continue;
                };
                let mut state = paths.lock().unwrap();
                if cancel.load(Ordering::Relaxed) || state.finished {
                    break;
                }
                if !state.walked.contains(&key)
                    && state.early.insert(key)
                    && send.send(entry).is_err()
                {
                    break;
                }
            }
            let mut state = paths.lock().unwrap();
            state.finished = true;
            state.walked.clear();
        });
        search.starting = Some(starting);
        search.preview = Some(receive);
        search
    }

    pub fn try_recv_hit(&mut self) -> Result<(MatchKind, Entry), mpsc::TryRecvError> {
        if let Some(rx) = &self.preview {
            match rx.try_recv() {
                Ok(hit) => return Ok((MatchKind::Exact, hit)),
                Err(mpsc::TryRecvError::Disconnected) => self.preview = None,
                Err(mpsc::TryRecvError::Empty) => {}
            }
        }
        if let Some(rx) = &self.starting {
            let walk = rx.try_recv()?;
            walk.set_paused(self.paused);
            self.walk = Some(walk);
            self.starting = None;
        }
        let result = self.walk.as_ref().unwrap().try_recv_hit();
        if matches!(result, Err(mpsc::TryRecvError::Disconnected)) {
            // The full walk owns completion. A stalled optional location never keeps it alive.
            self.cancel.store(true, Ordering::Relaxed);
            if let Some(hit) = self.preview.as_ref().and_then(|rx| rx.try_recv().ok()) {
                return Ok((MatchKind::Exact, hit));
            }
            self.preview = None;
        }
        result
    }

    pub fn set_paused(&mut self, paused: bool) {
        self.paused = paused;
        if let Some(walk) = &self.walk {
            walk.set_paused(paused);
        }
    }
    pub fn pending(&self) -> Option<usize> {
        self.walk.as_ref().map(Search::pending)
    }
}
impl Drop for WindowsSearch {
    fn drop(&mut self) {
        self.cancel.store(true, Ordering::Relaxed);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::{Duration, Instant};

    const TIMEOUT: Duration = Duration::from_secs(10);
    fn permit() -> Option<Permit> {
        Permit::acquire(Arc::default())
    }
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
    fn ordinary_searches_do_no_system_work() {
        let temp = tempfile::tempdir().unwrap();
        fs::write(temp.path().join("report.txt"), b"").unwrap();
        for query in [
            "report",
            "*.txt",
            "regex:report",
            "fuzzy:report",
            "glob:*.txt",
        ] {
            let root = temp.path().to_owned();
            let mut scan = WindowsSearch::start_with(
                SearchQuery::parse(query),
                token(),
                FileFilter::All,
                move |_| vec![root],
                || panic!("ordinary query attempted to start a probe"),
                || panic!("looked up system directories"),
                |_, _| panic!("inspected an executable"),
            );
            assert_eq!(poll(|| scan.try_recv_hit()).unwrap().1.name, "report.txt");
            assert!(poll(|| scan.try_recv_hit()).is_none());
            assert_eq!(scan.pending(), Some(0));
            scan.set_paused(false);
        }
    }

    #[test]
    fn exact_hit_precedes_discovery_and_a_slow_secondary_probe_cannot_delay_walk_or_completion() {
        let temp = tempfile::tempdir().unwrap();
        let system = temp.path().join("system");
        let other = temp.path().join("other");
        fs::create_dir(&system).unwrap();
        fs::create_dir(&other).unwrap();
        fs::write(system.join("tool.exe"), b"first").unwrap();
        fs::write(other.join("tool.exe"), b"copy").unwrap();
        fs::write(other.join("tool.exe.bak"), b"partial").unwrap();
        let (release_walk, walk_gate) = mpsc::channel();
        let (entered_secondary, secondary) = mpsc::channel();
        let (release_probe, probe_gate) = mpsc::channel();
        let (exited, exit) = mpsc::channel();
        let root = temp.path().to_owned();
        let candidate = system.join("tool.exe");
        let expected = candidate.clone();
        let mut scan = WindowsSearch::start_with(
            SearchQuery::parse("tool.exe"),
            token(),
            FileFilter::All,
            move |_| {
                walk_gate.recv_timeout(TIMEOUT).unwrap();
                vec![root]
            },
            permit,
            move || vec![system.clone(), system.clone(), system.join("blocked")],
            move |path, filter| {
                if path == candidate {
                    return lookup(path, filter);
                }
                entered_secondary.send(()).unwrap();
                probe_gate.recv_timeout(TIMEOUT).unwrap();
                exited.send(()).unwrap();
                None
            },
        );
        secondary.recv_timeout(TIMEOUT).unwrap();
        let (kind, hit) = poll(|| scan.try_recv_hit()).unwrap();
        assert_eq!(kind, MatchKind::Exact);
        assert_eq!((hit.path, hit.size), (expected, Some(5)));
        release_walk.send(()).unwrap();
        let mut remaining = Vec::new();
        while let Some((kind, entry)) = poll(|| scan.try_recv_hit()) {
            remaining.push((entry.name, kind));
        }
        remaining.sort_by(|a, b| a.0.cmp(&b.0));
        assert_eq!(
            remaining,
            [
                ("tool.exe".into(), MatchKind::Exact),
                ("tool.exe.bak".into(), MatchKind::Partial)
            ]
        );
        release_probe.send(()).unwrap();
        exit.recv_timeout(TIMEOUT).unwrap();
    }

    #[test]
    fn system_lookup_uses_the_literal_accented_and_mixed_case_filename() {
        let temp = tempfile::tempdir().unwrap();
        let root = temp.path().to_owned();
        let disk_name = "CaféTool.EXE";
        let expected = root.join(disk_name);
        fs::write(&expected, b"file").unwrap();
        let (release, gate) = mpsc::channel();
        let (called, candidate) = mpsc::channel();
        let mut scan = WindowsSearch::start_with(
            SearchQuery::parse("  CaféTool.EXE  "),
            token(),
            FileFilter::WindowsExecutables,
            move |_| {
                let _ = gate.recv_timeout(TIMEOUT);
                vec![]
            },
            permit,
            move || vec![root],
            move |p, filter| {
                called.send(p.to_owned()).unwrap();
                lookup(p, filter)
            },
        );
        assert_eq!(candidate.recv_timeout(TIMEOUT).unwrap(), expected);
        let (kind, hit) = poll(|| scan.try_recv_hit()).unwrap();
        assert_eq!(
            (kind, hit.name, hit.path),
            (MatchKind::Exact, disk_name.to_owned(), expected)
        );
        release.send(()).unwrap();
    }

    #[test]
    fn walk_first_hit_is_unique_and_cancelling_revokes_a_blocked_probe() {
        for cancel_after_first in [false, true] {
            let temp = tempfile::tempdir().unwrap();
            let root = temp.path().to_owned();
            fs::write(root.join("tool.exe"), b"ordinary").unwrap();
            let (entered, started) = mpsc::channel();
            let (release, gate) = mpsc::channel();
            let (exited, exit) = mpsc::channel();
            let cancel = token();
            let dir = root.clone();
            let mut scan = WindowsSearch::start_with(
                SearchQuery::parse("tool.exe"),
                cancel.clone(),
                FileFilter::All,
                move |_| vec![root],
                permit,
                move || vec![dir],
                move |path, filter| {
                    entered.send(()).unwrap();
                    gate.recv_timeout(TIMEOUT).unwrap();
                    let result = lookup(path, filter);
                    exited.send(()).unwrap();
                    result
                },
            );
            started.recv_timeout(TIMEOUT).unwrap();
            assert_eq!(poll(|| scan.try_recv_hit()).unwrap().1.name, "tool.exe");
            if cancel_after_first {
                drop(scan);
                assert!(cancel.load(Ordering::Relaxed));
                release.send(()).unwrap();
            } else {
                release.send(()).unwrap();
                assert!(poll(|| scan.try_recv_hit()).is_none());
            }
            exit.recv_timeout(TIMEOUT).unwrap();
        }
    }

    #[test]
    fn absent_exe_costs_one_literal_lookup_per_dir_and_invalid_names_skip_lookup() {
        let temp = tempfile::tempdir().unwrap();
        let base = temp.path().to_owned();
        let dirs = [base.join("a"), base.join("b"), base.join("c")];
        let expected = dirs.clone().map(|p| p.join("missing.exe"));
        let (sent, calls) = mpsc::channel();
        let (release, gate) = mpsc::channel();
        let mut scan = WindowsSearch::start_with(
            SearchQuery::parse("missing.exe"),
            token(),
            FileFilter::All,
            move |_| {
                gate.recv_timeout(TIMEOUT).unwrap();
                vec![base]
            },
            permit,
            move || dirs.to_vec(),
            move |p, filter| {
                sent.send(p.to_owned()).unwrap();
                lookup(p, filter)
            },
        );
        for path in expected {
            assert_eq!(calls.recv_timeout(TIMEOUT).unwrap(), path);
        }
        release.send(()).unwrap();
        assert!(poll(|| scan.try_recv_hit()).is_none());
        for text in [
            "notepad",
            "regex:notepad.exe",
            "*.exe",
            "fuzzy:notepad.exe",
            r"sub\tool.exe",
            "aux.exe",
            "lpt1.exe",
            "c:thing.exe",
            "com¹.exe",
            "file?.exe",
        ] {
            assert!(
                SearchQuery::parse(text).executable_filename().is_none(),
                "{text}"
            );
        }
        let limit = Arc::default();
        let a = Permit::acquire(Arc::clone(&limit)).unwrap();
        let _b = Permit::acquire(Arc::clone(&limit)).unwrap();
        assert!(Permit::acquire(Arc::clone(&limit)).is_none());
        drop(a);
        assert!(Permit::acquire(limit).is_some());
    }

    #[cfg(windows)]
    #[test]
    fn literal_lookup_preserves_disk_case_and_ignores_directories() {
        let temp = tempfile::tempdir().unwrap();
        let real = temp.path().join("MiXeD-Tool.EXE");
        fs::write(&real, b"123").unwrap();
        fs::create_dir(temp.path().join("folder.exe")).unwrap();
        let (_, hit) = lookup(
            &temp.path().join("mixed-tool.exe"),
            FileFilter::WindowsExecutables,
        )
        .unwrap();
        assert_eq!(hit.name, "MiXeD-Tool.EXE");
        assert_eq!(hit.path, real);
        assert_eq!(hit.size, Some(3));
        assert!(lookup(&temp.path().join("folder.exe"), FileFilter::All).is_none());
    }

    #[cfg(windows)]
    #[test]
    #[ignore = "paired startup measurement on a Windows runner"]
    fn compare_startup_to_ordinary_walk() {
        let fixture = tempfile::tempdir().unwrap();
        fs::write(fixture.path().join("report.txt"), b"").unwrap();
        for (text, expected) in [
            ("report", Some("report.txt")),
            ("drill-absent-9c3a.exe", None),
        ] {
            let mut base = Vec::new();
            let mut changed = Vec::new();
            for pair in 0..7 {
                for preview in [pair % 2 == 0, pair % 2 != 0] {
                    let root = fixture.path().to_owned();
                    // Exercise real Windows drive discovery in both paths, and confine the walk
                    // to the identical fixture for an observable first result or complete miss.
                    let discover = move |stop: &AtomicBool| {
                        let _ = default_roots_with_cancel(stop);
                        vec![root]
                    };
                    let started = Instant::now();
                    let cancel = token();
                    let query = SearchQuery::parse(text);
                    let hit = if preview {
                        let mut search = WindowsSearch::start_with(
                            query,
                            cancel,
                            FileFilter::All,
                            discover,
                            permit,
                            system_dirs,
                            lookup,
                        );
                        poll(|| search.try_recv_hit())
                    } else {
                        let roots = discover(&cancel);
                        let search = Search::start_filtered(query, roots, cancel, FileFilter::All);
                        poll(|| search.try_recv_hit())
                    };
                    let elapsed = started.elapsed();
                    assert_eq!(hit.as_ref().map(|(_, entry)| entry.name.as_str()), expected);
                    if pair > 0 {
                        if preview {
                            changed.push(elapsed);
                        } else {
                            base.push(elapsed);
                        }
                    }
                }
            }
            base.sort();
            changed.sort();
            eprintln!("native startup {text:?}, 6 alternating pairs after warmup, middle pair: ordinary {:?}/{:?}, new {:?}/{:?}",base[2],base[3],changed[2],changed[3]);
        }
    }

    #[cfg(windows)]
    #[test]
    #[ignore = "requires an installed Windows Notepad"]
    fn installed_notepad_in_both_modes() {
        let root = PathBuf::from(std::env::var_os("SystemRoot").unwrap());
        let expected = [root.join("System32/notepad.exe"), root.join("notepad.exe")];
        for filter in [FileFilter::All, FileFilter::WindowsExecutables] {
            let start = Instant::now();
            let mut search =
                WindowsSearch::start(SearchQuery::parse("NOTEPAD.EXE"), token(), filter);
            let (kind, hit) = poll(|| search.try_recv_hit()).unwrap();
            let elapsed = start.elapsed();
            assert_eq!(kind, MatchKind::Exact);
            let found = fs::canonicalize(&hit.path).unwrap();
            assert!(expected
                .iter()
                .filter_map(|p| fs::canonicalize(p).ok())
                .any(|p| p == found));
            eprintln!(
                "{filter:?} first native Notepad {elapsed:?}: {}",
                hit.path.display()
            );
        }
    }
}
