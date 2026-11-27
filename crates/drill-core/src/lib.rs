#![forbid(unsafe_code)]
use std::cmp::Reverse;
use std::collections::{BinaryHeap, HashSet, VecDeque};
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{mpsc, Arc, Condvar, Mutex, OnceLock};
use std::thread::{self, JoinHandle};
use std::time::SystemTime;
#[cfg(any(windows, test))]
mod windows_startup;
pub use drill_query::{matches, MatchKind, SearchQuery};
#[cfg(windows)]
pub use windows_startup::WindowsSearch;

#[derive(Clone, Debug)]
pub struct Entry {
    pub path: PathBuf,
    pub name: String,
    pub size: Option<u64>,
    pub modified: Option<SystemTime>,
    pub is_dir: bool,
}

// The platform root files are embedded, so running a binary from another directory works.
pub fn default_roots() -> Vec<PathBuf> {
    default_roots_with_cancel(&AtomicBool::new(false))
}

/// Discovers platform roots, checking cancellation between filesystem operations.
pub fn default_roots_with_cancel(cancel: &AtomicBool) -> Vec<PathBuf> {
    let config = if cfg!(target_os = "windows") {
        include_str!("../../../src/assets/roots_windows.txt")
    } else if cfg!(target_os = "macos") {
        include_str!("../../../src/assets/roots_mac.txt")
    } else {
        include_str!("../../../src/assets/roots_linux.txt")
    };
    let home = std::env::var_os(if cfg!(windows) { "USERPROFILE" } else { "HOME" })
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("."));
    let mut roots = Vec::new();
    for line in config
        .lines()
        .map(str::trim)
        .filter(|line| !line.is_empty() && !line.starts_with('#'))
    {
        if cancel.load(Ordering::Relaxed) {
            break;
        }
        let mut expanded = line.to_string();
        if expanded.starts_with('~') {
            expanded = format!("{}{}", home.to_string_lossy(), &expanded[1..]);
        }
        for (key, value) in std::env::vars_os() {
            if let (Some(key), Some(value)) = (key.to_str(), value.to_str()) {
                expanded = expanded.replace(&format!("%{key}%"), value);
            }
        }
        let candidates: Vec<PathBuf> = if let Some(suffix) = expanded.strip_prefix("*:") {
            ('C'..='Z')
                .map(|drive| PathBuf::from(format!("{drive}:{suffix}")))
                .collect()
        } else {
            vec![PathBuf::from(expanded)]
        };
        for path in candidates {
            if cancel.load(Ordering::Relaxed) {
                break;
            }
            let path_text = path.to_string_lossy();
            if let Some(prefix) = path_text.strip_suffix('*') {
                let directory_wildcard = prefix.ends_with('/') || prefix.ends_with('\\');
                let parent = if directory_wildcard {
                    Path::new(prefix)
                } else {
                    Path::new(prefix).parent().unwrap_or(Path::new(prefix))
                };
                let name_prefix = if directory_wildcard {
                    "".into()
                } else {
                    Path::new(prefix)
                        .file_name()
                        .unwrap_or_default()
                        .to_string_lossy()
                };
                if let Ok(entries) = fs::read_dir(parent) {
                    roots.extend(
                        entries
                            .flatten()
                            .take_while(|_| !cancel.load(Ordering::Relaxed))
                            .filter(|e| {
                                e.file_name()
                                    .to_string_lossy()
                                    .starts_with(name_prefix.as_ref())
                                    && e.path().is_dir()
                            })
                            .map(|e| e.path()),
                    );
                }
            } else if path.is_dir() {
                roots.push(path);
            }
        }
    }
    #[cfg(target_os = "linux")]
    if !cancel.load(Ordering::Relaxed) {
        let candidates = desktop_roots(
            &home,
            std::env::var_os("XDG_DATA_HOME").as_deref(),
            std::env::var_os("XDG_DATA_DIRS").as_deref(),
        );
        roots.extend(
            candidates
                .into_iter()
                .take_while(|_| !cancel.load(Ordering::Relaxed))
                .filter(|dir| dir.is_dir()),
        );
    }
    if roots.is_empty() && !cancel.load(Ordering::Relaxed) {
        roots.push(home);
    }
    roots.sort();
    roots.dedup();
    roots
}

#[cfg(target_os = "linux")]
fn desktop_roots(
    home: &Path,
    data_home: Option<&std::ffi::OsStr>,
    data_dirs: Option<&std::ffi::OsStr>,
) -> Vec<PathBuf> {
    let user_dir = data_home
        .map(Path::new)
        .filter(|dir| dir.is_absolute())
        .map(Path::to_owned)
        .unwrap_or_else(|| home.join(".local/share"));
    let system_dirs = data_dirs
        .filter(|dirs| !dirs.is_empty())
        .unwrap_or(std::ffi::OsStr::new("/usr/local/share:/usr/share"));
    std::iter::once(user_dir)
        .chain(std::env::split_paths(system_dirs).filter(|dir| dir.is_absolute()))
        .map(|dir| dir.join("applications"))
        .collect()
}

mod file_filter;
pub use file_filter::FileFilter;

impl FileFilter {
    fn accepts(self, path: &Path, kind: fs::FileType) -> bool {
        self.accepts_extension(
            path.extension().unwrap_or_default(),
            kind.is_dir(),
            kind.is_file(),
        )
    }
}

type Priority = Reverse<(bool, bool, usize, usize, Reverse<u64>, PathBuf)>;

fn priority(path: PathBuf) -> Priority {
    static DICTIONARY: OnceLock<HashSet<&'static str>> = OnceLock::new();
    let words = DICTIONARY.get_or_init(|| {
        include_str!("../../../src/assets/wordsalpha.txt")
            .lines()
            .collect()
    });
    let name = path
        .file_name()
        .unwrap_or_default()
        .to_string_lossy()
        .to_lowercase();
    let text = path.to_string_lossy();
    #[cfg(windows)]
    let system_attribute = {
        use std::os::windows::fs::MetadataExt;
        fs::metadata(&path)
            .map(|m| m.file_attributes() & 0x6 != 0)
            .unwrap_or(false)
    };
    #[cfg(not(windows))]
    let system_attribute = false;
    let hidden = system_attribute
        || name.starts_with('.')
        || name.ends_with('~')
        || name.ends_with(".app")
        || [
            "/System",
            "/Library",
            "/private",
            "/usr",
            "/bin",
            "/sbin",
            "C:\\Windows",
            "C:\\ProgramData",
        ]
        .iter()
        .any(|p| text.starts_with(p));
    let depth = path.components().count();
    let len = text.len();
    let modified = fs::metadata(&path)
        .and_then(|m| m.modified())
        .ok()
        .and_then(|t| t.duration_since(SystemTime::UNIX_EPOCH).ok())
        .map_or(0, |d| d.as_secs());
    Reverse((
        !words.contains(name.as_str()),
        hidden,
        depth,
        len,
        Reverse(modified),
        path,
    ))
}

// Resolve the containing directory so overlapping roots agree, while keeping a
// distinct directory entry for links to the same file.
fn entry_key(path: &Path) -> Option<PathBuf> {
    Some(
        fs::canonicalize(path.parent()?)
            .ok()?
            .join(path.file_name()?),
    )
}

// Keep only a bounded window of ordinary exact hits while a system lookup is
// outstanding. Once there are already many exact hits, the walk owns all new ones.
#[derive(Default)]
struct PreviewPaths {
    early: HashSet<PathBuf>,
    walked: HashSet<PathBuf>,
    finished: bool,
}
impl PreviewPaths {
    fn admit_walk(shared: &Mutex<Self>, path: &Path) -> bool {
        {
            let state = shared.lock().unwrap();
            if state.finished && state.early.is_empty() {
                return true;
            }
        }
        let Some(key) = entry_key(path) else {
            return true;
        };
        let mut state = shared.lock().unwrap();
        let already_sent = state.early.remove(&key);
        if !state.finished {
            state.walked.insert(key);
            if state.walked.len() >= 32 {
                state.finished = true;
                state.walked.clear();
            }
        }
        !already_sent
    }
}

type RootDiscovery = Box<dyn FnOnce(&AtomicBool) -> Vec<PathBuf> + Send>;

struct Work {
    seeds: VecDeque<PathBuf>,
    queue: BinaryHeap<Priority>,
    outstanding: usize,
    visited: HashSet<PathBuf>,
}

fn complete_directory((lock, cv): &(Mutex<Work>, Condvar)) {
    let mut state = lock.lock().unwrap();
    state.outstanding -= 1;
    if state.outstanding == 0 {
        cv.notify_all();
    }
}

// Pause only at cancellation-safe points, without holding the directory queue lock.
fn wait_while_paused(paused: &AtomicBool, cancel: &AtomicBool, work: &(Mutex<Work>, Condvar)) {
    if paused.load(Ordering::Relaxed) {
        let guard = work.0.lock().unwrap();
        drop(
            work.1
                .wait_while(guard, |_| {
                    paused.load(Ordering::Relaxed) && !cancel.load(Ordering::Relaxed)
                })
                .unwrap(),
        );
    }
}

pub struct Search {
    receiver: mpsc::Receiver<(MatchKind, Entry)>,
    paused: Arc<AtomicBool>,
    cancel: Arc<AtomicBool>,
    work: Arc<(Mutex<Work>, Condvar)>,
    workers: Vec<JoinHandle<()>>,
}
impl Search {
    pub fn start(query: String, roots: Vec<PathBuf>) -> Self {
        Self::start_with_cancel(query, roots, Arc::new(AtomicBool::new(false)))
    }

    /// Cancels startup when the token is set. After startup, call `stop` instead.
    /// An in-flight filesystem call may finish before startup stops.
    pub fn start_with_cancel(
        query: String,
        roots: Vec<PathBuf>,
        startup_cancel: Arc<AtomicBool>,
    ) -> Self {
        Self::start_prepared_with_cancel(SearchQuery::parse(&query), roots, startup_cancel)
    }

    pub fn start_prepared_with_cancel(
        query: SearchQuery,
        roots: Vec<PathBuf>,
        startup_cancel: Arc<AtomicBool>,
    ) -> Self {
        Self::start_filtered(query, roots, startup_cancel, FileFilter::All)
    }

    pub fn start_filtered(
        query: SearchQuery,
        roots: Vec<PathBuf>,
        startup_cancel: Arc<AtomicBool>,
        filter: FileFilter,
    ) -> Self {
        Self::start_walk(query, roots, None, startup_cancel, filter, None)
    }

    #[cfg(any(windows, test))]
    fn start_seeded(
        query: SearchQuery,
        seeds: Vec<PathBuf>,
        discover: impl FnOnce(&AtomicBool) -> Vec<PathBuf> + Send + 'static,
        startup_cancel: Arc<AtomicBool>,
        filter: FileFilter,
        previews: Option<Arc<Mutex<PreviewPaths>>>,
    ) -> Self {
        Self::start_walk(
            query,
            seeds,
            Some(Box::new(discover)),
            startup_cancel,
            filter,
            previews,
        )
    }

    fn start_walk(
        query: SearchQuery,
        roots: Vec<PathBuf>,
        discover: Option<RootDiscovery>,
        startup_cancel: Arc<AtomicBool>,
        filter: FileFilter,
        previews: Option<Arc<Mutex<PreviewPaths>>>,
    ) -> Self {
        let valid = query.error().is_none();
        let seeded = discover.is_some();
        let discover = discover.filter(|_| valid && !startup_cancel.load(Ordering::Relaxed));
        let query = Arc::new(query);
        let paused = Arc::new(AtomicBool::new(false));
        let (tx, receiver) = mpsc::sync_channel(512);
        let cancel = if seeded {
            startup_cancel.clone()
        } else {
            Arc::new(AtomicBool::new(false))
        };
        let mut visited = HashSet::new();
        let (seeds, queue) = if seeded {
            // Resolve each seed from its worker so a redirected directory cannot hold up startup.
            let seeds = if discover.is_some() {
                roots.into()
            } else {
                VecDeque::new()
            };
            (seeds, BinaryHeap::new())
        } else {
            let roots: Vec<PathBuf> = roots
                .into_iter()
                .take_while(|_| valid && !startup_cancel.load(Ordering::Relaxed))
                .filter(|p| {
                    fs::canonicalize(p)
                        .ok()
                        .is_some_and(|canonical| visited.insert(canonical))
                })
                .collect();
            let queue = roots
                .into_iter()
                .take_while(|_| !startup_cancel.load(Ordering::Relaxed))
                .map(priority)
                .collect();
            (VecDeque::new(), queue)
        };
        // Leave room for ordinary work even if every seed worker blocks on I/O.
        let count = thread::available_parallelism()
            .map_or(4, |v| v.get())
            .max(seeds.len().saturating_add(1))
            .clamp(1, 16);
        // Discovery stays outstanding while workers drain the seed directories.
        let outstanding = seeds.len() + queue.len() + usize::from(discover.is_some());
        let work = Arc::new((
            Mutex::new(Work {
                seeds,
                queue,
                outstanding,
                visited,
            }),
            Condvar::new(),
        ));
        let mut workers = Vec::new();
        for _ in 0..count {
            if outstanding == 0 || startup_cancel.load(Ordering::Relaxed) {
                break;
            }
            let (tx, cancel, work, query) =
                (tx.clone(), cancel.clone(), work.clone(), query.clone());
            let paused = paused.clone();
            let previews = previews.clone();
            workers.push(thread::spawn(move || loop {
                let (dir, seed) = {
                    let (lock, cv) = &*work;
                    let mut state = lock.lock().unwrap();
                    loop {
                        if cancel.load(Ordering::Relaxed) || state.outstanding == 0 {
                            return;
                        }
                        if !paused.load(Ordering::Relaxed) {
                            if let Some(seed) = state.seeds.pop_front() {
                                break (seed, true);
                            }
                            if let Some(Reverse((_, _, _, _, _, dir))) = state.queue.pop() {
                                break (dir, false);
                            }
                        }
                        state = cv.wait(state).unwrap();
                    }
                };
                if seed {
                    let claimed = fs::canonicalize(&dir).ok().is_some_and(|canonical| {
                        let mut state = work.0.lock().unwrap();
                        !cancel.load(Ordering::Relaxed) && state.visited.insert(canonical)
                    });
                    if !claimed {
                        complete_directory(&work);
                        continue;
                    }
                }
                if let Ok(entries) = fs::read_dir(dir) {
                    for item in entries.flatten() {
                        wait_while_paused(&paused, &cancel, &work);
                        if cancel.load(Ordering::Relaxed) {
                            break;
                        }
                        let path = item.path();
                        let Ok(kind) = item.file_type() else { continue };
                        let accepted = filter.accepts(&path, kind);
                        if kind.is_dir()
                            && !kind.is_symlink()
                            && !(filter == FileFilter::MacBundles && accepted)
                        {
                            let canonical =
                                fs::canonicalize(&path).unwrap_or_else(|_| path.clone());
                            let ranked = priority(path.clone());
                            let (lock, cv) = &*work;
                            let mut state = lock.lock().unwrap();
                            if state.visited.insert(canonical) {
                                state.queue.push(ranked);
                                state.outstanding += 1;
                                cv.notify_one();
                            }
                        }
                        if !accepted {
                            continue;
                        }
                        let name = item.file_name().to_string_lossy().into_owned();
                        let rank = if filter != FileFilter::All
                            && path
                                .file_stem()
                                .is_some_and(|stem| query.exact_stem(&stem.to_string_lossy()))
                        {
                            Some(MatchKind::Exact)
                        } else {
                            query.classify(&name)
                        };
                        if let Some(rank) = rank {
                            if rank == MatchKind::Exact {
                                if let Some(previews) = &previews {
                                    if !PreviewPaths::admit_walk(previews, &path) {
                                        continue;
                                    }
                                }
                            }
                            let metadata = item.metadata().ok();
                            let entry = Entry {
                                path,
                                name,
                                size: metadata.as_ref().map(|m| m.len()),
                                modified: metadata.and_then(|m| m.modified().ok()),
                                is_dir: kind.is_dir(),
                            };
                            let mut hit = (rank, entry);
                            loop {
                                wait_while_paused(&paused, &cancel, &work);
                                if cancel.load(Ordering::Relaxed) {
                                    return;
                                }
                                match tx.try_send(hit) {
                                    Ok(()) => break,
                                    Err(mpsc::TrySendError::Full(returned)) => {
                                        hit = returned;
                                        thread::sleep(std::time::Duration::from_millis(5));
                                    }
                                    Err(mpsc::TrySendError::Disconnected(_)) => return,
                                }
                            }
                        }
                    }
                }
                complete_directory(&work);
            }));
        }
        if let Some(discover) = discover {
            if !cancel.load(Ordering::Relaxed) {
                let (cancel, work) = (cancel.clone(), work.clone());
                workers.push(thread::spawn(move || {
                    let (lock, cv) = &*work;
                    if !cancel.load(Ordering::Relaxed) {
                        for root in discover(&cancel) {
                            if cancel.load(Ordering::Relaxed) {
                                break;
                            }
                            let Ok(canonical) = fs::canonicalize(&root) else {
                                continue;
                            };
                            if cancel.load(Ordering::Relaxed) {
                                break;
                            }
                            let ranked = priority(root);
                            let mut state = lock.lock().unwrap();
                            if !cancel.load(Ordering::Relaxed) && state.visited.insert(canonical) {
                                state.queue.push(ranked);
                                state.outstanding += 1;
                                cv.notify_one();
                            }
                        }
                    }
                    lock.lock().unwrap().outstanding -= 1;
                    cv.notify_all();
                }));
            } else {
                work.0.lock().unwrap().outstanding -= 1;
            }
        }
        let search = Self {
            receiver,
            paused,
            cancel,
            work,
            workers,
        };
        if startup_cancel.load(Ordering::Relaxed) {
            search.stop();
        }
        search
    }
    pub fn try_recv(&self) -> Result<Entry, mpsc::TryRecvError> {
        self.try_recv_hit().map(|(_, entry)| entry)
    }
    pub fn try_recv_hit(&self) -> Result<(MatchKind, Entry), mpsc::TryRecvError> {
        self.receiver.try_recv()
    }
    pub fn set_paused(&self, paused: bool) {
        let _guard = self.work.0.lock().unwrap();
        self.paused.store(paused, Ordering::Relaxed);
        if !paused {
            self.work.1.notify_all();
        }
    }
    pub fn pending(&self) -> usize {
        self.work.0.lock().unwrap().outstanding
    }
    pub fn done(&self) -> bool {
        self.workers.iter().all(JoinHandle::is_finished)
    }
    pub fn stop(&self) {
        let _guard = self.work.0.lock().unwrap();
        self.cancel.store(true, Ordering::Relaxed);
        self.work.1.notify_all();
    }
}
impl Drop for Search {
    fn drop(&mut self) {
        self.stop();
    }
}

#[cfg(test)]
mod test_directory;

#[cfg(test)]
mod tests {
    use super::test_directory::private_temp_dir;
    use super::*;
    #[test]
    fn invalid_patterns_never_start_a_walk_or_match_their_own_text() {
        for text in [
            "regex:",
            "glob:",
            "regex:(",
            "glob:bad[",
            "glob:{{{{{{{{{a,b}}}}}}}}}",
        ] {
            let query = SearchQuery::parse(text);
            assert!(query.error().is_some(), "{text}");
            assert_eq!(query.classify(text), None);
            let search = Search::start(text.into(), vec![std::env::temp_dir()]);
            assert!(search.done());
            assert_eq!(search.pending(), 0);
        }
    }

    #[test]
    fn app_filters_use_file_type_and_ignore_case_before_delivering_results() {
        let root = private_temp_dir();
        for dir in ["Real.APP/Contents/Nested.app", "fake.exe"] {
            fs::create_dir_all(root.path().join(dir)).unwrap();
        }
        for file in ["fake.app", "Real.EXE", "Real.exe.bak"] {
            fs::write(root.path().join(file), []).unwrap();
        }
        for (filter, expected) in [
            (FileFilter::MacBundles, "Real.APP"),
            (FileFilter::WindowsExecutables, "Real.EXE"),
        ] {
            for (text, rank) in [
                ("", MatchKind::Partial),
                ("real", MatchKind::Exact),
                (expected, MatchKind::Exact),
                ("real.*", MatchKind::Partial),
                ("regex:^real[.]", MatchKind::Partial),
            ] {
                let search = Search::start_filtered(
                    SearchQuery::parse(text),
                    vec![root.path().into()],
                    Arc::new(AtomicBool::new(false)),
                    filter,
                );
                let (kind, item) = search
                    .receiver
                    .recv_timeout(std::time::Duration::from_secs(5))
                    .unwrap();
                assert_eq!((kind, item.name.as_str()), (rank, expected));
                assert!(matches!(
                    search
                        .receiver
                        .recv_timeout(std::time::Duration::from_secs(5)),
                    Err(mpsc::RecvTimeoutError::Disconnected)
                ));
            }
        }
    }

    #[cfg(target_os = "linux")]
    #[test]
    fn desktop_files_follow_xdg_search_directories() {
        let dirs = desktop_roots(
            Path::new("/home/example"),
            Some("/user-data".as_ref()),
            Some("/first:relative:/second".as_ref()),
        );
        assert_eq!(
            dirs,
            [
                Path::new("/user-data/applications"),
                Path::new("/first/applications"),
                Path::new("/second/applications")
            ]
        );
        let defaults = desktop_roots(Path::new("/home/example"), None, Some("".as_ref()));
        assert!(defaults.contains(&PathBuf::from("/usr/share/applications")));
        assert!(defaults.contains(&PathBuf::from("/home/example/.local/share/applications")));
    }

    #[test]
    fn priorities_favor_dictionary_and_visible_directories() {
        let dictionary = priority(PathBuf::from("/home/user/music"));
        let nondictionary = priority(PathBuf::from("/home/user/zzzzqxyz"));
        assert!(dictionary > nondictionary);
        let visible = priority(PathBuf::from("/home/user/zzzzqxyz"));
        let hidden = priority(PathBuf::from("/home/user/.zzzzqxyz"));
        assert!(visible > hidden);
    }
    #[test]
    fn cancellation_completes_even_when_results_are_not_consumed() {
        let directory = private_temp_dir();
        let root = directory.path();
        for n in 0..700 {
            fs::write(root.join(format!("match-{n}")), "x").unwrap();
        }
        for paused in [false, true] {
            let search = Search::start("match".into(), vec![root.to_path_buf()]);
            if paused {
                search.set_paused(true);
            }
            std::thread::sleep(std::time::Duration::from_millis(300));
            search.stop();
            let deadline = std::time::Instant::now() + std::time::Duration::from_secs(5);
            while !search.done() && std::time::Instant::now() < deadline {
                std::thread::yield_now();
            }
            assert!(
                search.done(),
                "cancelled search did not stop (paused={paused})"
            );
        }
    }
    #[test]
    fn seed_results_arrive_during_discovery_and_overlapping_roots_share_the_walk() {
        let fixture = private_temp_dir();
        let root = fixture.path().to_owned();
        let seed = root.join("seed");
        fs::create_dir_all(seed.join("nested")).unwrap();
        fs::write(seed.join("needle-seed"), []).unwrap();
        fs::write(seed.join("nested/needle-nested"), []).unwrap();
        fs::write(root.join("needle-discovered"), []).unwrap();
        let (release, blocked) = mpsc::channel();
        let timeout = std::time::Duration::from_secs(5);
        let search = Search::start_seeded(
            SearchQuery::parse("needle"),
            vec![seed.clone()],
            move |_| {
                if blocked.recv_timeout(timeout).is_err() {
                    return Vec::new();
                }
                vec![root, seed]
            },
            Arc::default(),
            FileFilter::All,
            None,
        );
        let (_, first) = search.receiver.recv_timeout(timeout).unwrap();
        let (_, second) = search.receiver.recv_timeout(timeout).unwrap();
        let mut names = [first.name, second.name];
        names.sort();
        assert_eq!(names, ["needle-nested", "needle-seed"]);
        assert!(search.pending() > 0);
        assert!(matches!(
            search.try_recv_hit(),
            Err(mpsc::TryRecvError::Empty)
        ));

        release.send(()).unwrap();
        let (_, last) = search.receiver.recv_timeout(timeout).unwrap();
        assert_eq!(last.name, "needle-discovered");
        assert!(matches!(
            search.receiver.recv_timeout(timeout),
            Err(mpsc::RecvTimeoutError::Disconnected)
        ));
        assert_eq!(search.pending(), 0);
    }

    #[test]
    fn stopping_a_paused_seeded_search_cancels_discovery_and_wakes_the_walk() {
        let (entered, started) = mpsc::channel();
        let (cancelled, observed) = mpsc::channel();
        let timeout = std::time::Duration::from_secs(5);
        let search = Search::start_seeded(
            SearchQuery::parse("needle"),
            vec![],
            move |cancel| {
                let deadline = std::time::Instant::now() + timeout;
                entered.send(()).unwrap();
                while !cancel.load(Ordering::Relaxed) && std::time::Instant::now() < deadline {
                    thread::yield_now();
                }
                cancelled.send(cancel.load(Ordering::Relaxed)).unwrap();
                vec![]
            },
            Arc::default(),
            FileFilter::All,
            None,
        );
        started.recv_timeout(timeout).unwrap();
        search.set_paused(true);
        search.stop();
        assert!(observed.recv_timeout(timeout).unwrap());
        assert!(matches!(
            search.receiver.recv_timeout(timeout),
            Err(mpsc::RecvTimeoutError::Disconnected)
        ));
    }

    #[test]
    fn invalid_or_precancelled_seeded_searches_skip_discovery() {
        for (text, cancelled) in [("regex:(", false), ("needle", true)] {
            let search = Search::start_seeded(
                SearchQuery::parse(text),
                vec![std::env::temp_dir()],
                |_| panic!("discovery ran without an active query"),
                Arc::new(AtomicBool::new(cancelled)),
                FileFilter::All,
                None,
            );
            assert!(search.done());
            assert_eq!(search.pending(), 0);
        }
    }

    #[test]
    fn scan_finishes_and_finds_files_and_directories() {
        let directory = private_temp_dir();
        let root = directory.path();
        fs::create_dir_all(root.join("needle-folder")).unwrap();
        fs::write(root.join("needle-file.txt"), "x").unwrap();
        let search = Search::start(
            "needle".into(),
            vec![root.to_path_buf(), root.join("needle-folder")],
        );
        let mut names = Vec::new();
        loop {
            match search
                .receiver
                .recv_timeout(std::time::Duration::from_secs(5))
            {
                Ok((_, e)) => names.push(e.name),
                Err(mpsc::RecvTimeoutError::Disconnected) => break,
                Err(mpsc::RecvTimeoutError::Timeout) => {
                    panic!("search did not complete within five seconds")
                }
            }
        }
        assert!(names.contains(&"needle-file.txt".to_string()));
        assert!(names.contains(&"needle-folder".to_string()));
    }
}
