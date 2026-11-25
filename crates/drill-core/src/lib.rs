#![forbid(unsafe_code)]
use std::cmp::Reverse;
use std::collections::{BinaryHeap, HashSet};
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{mpsc, Arc, Condvar, Mutex, OnceLock};
use std::thread::{self, JoinHandle};
use std::time::SystemTime;
use unicode_normalization::{char::is_combining_mark, UnicodeNormalization};

#[derive(Clone, Debug)]
pub struct Entry {
    pub path: PathBuf,
    pub name: String,
    pub size: Option<u64>,
    pub modified: Option<SystemTime>,
    pub is_dir: bool,
}

fn normalized(text: &str) -> String {
    text.to_lowercase()
        .nfd()
        .filter(|c| !is_combining_mark(*c))
        .collect()
}

// Ratcliff/Obershelp matching, as used by Python's difflib.SequenceMatcher.
fn matching_chars(a: &[char], b: &[char]) -> usize {
    let mut best = (0, 0, 0);
    for i in 0..a.len() {
        for j in 0..b.len() {
            let mut n = 0;
            while i + n < a.len() && j + n < b.len() && a[i + n] == b[j + n] {
                n += 1;
            }
            if n > best.2 {
                best = (i, j, n);
            }
        }
    }
    if best.2 == 0 {
        0
    } else {
        best.2
            + matching_chars(&a[..best.0], &b[..best.1])
            + matching_chars(&a[best.0 + best.2..], &b[best.1 + best.2..])
    }
}

pub fn matches(name: &str, query: &str) -> bool {
    let (fuzzy, query) = query
        .strip_prefix("fuzzy:")
        .map_or((false, query), |q| (true, q));
    let name = normalized(name);
    let query = normalized(query);
    if fuzzy {
        query.split(' ').all(|token| {
            name.split_whitespace().any(|word| {
                let a: Vec<char> = token.chars().collect();
                let b: Vec<char> = word.chars().collect();
                !a.is_empty() && 4 * matching_chars(&b, &a) >= a.len() + b.len()
            })
        })
    } else {
        query.split(' ').all(|token| name.contains(token))
    }
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
    if roots.is_empty() && !cancel.load(Ordering::Relaxed) {
        roots.push(home);
    }
    roots.sort();
    roots.dedup();
    roots
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

struct Work {
    queue: BinaryHeap<Priority>,
    outstanding: usize,
    visited: HashSet<PathBuf>,
}
pub struct Search {
    receiver: mpsc::Receiver<Entry>,
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
        let (tx, receiver) = mpsc::sync_channel(512);
        let cancel = Arc::new(AtomicBool::new(false));
        let mut visited = HashSet::new();
        let roots: Vec<PathBuf> = roots
            .into_iter()
            .filter(|p| {
                !startup_cancel.load(Ordering::Relaxed)
                    && fs::canonicalize(p)
                        .ok()
                        .is_some_and(|canonical| visited.insert(canonical))
            })
            .collect();
        let queue: BinaryHeap<Priority> = roots
            .iter()
            .take_while(|_| !startup_cancel.load(Ordering::Relaxed))
            .cloned()
            .map(priority)
            .collect();
        let outstanding = queue.len();
        let work = Arc::new((
            Mutex::new(Work {
                queue,
                outstanding,
                visited,
            }),
            Condvar::new(),
        ));
        let count = thread::available_parallelism()
            .map_or(4, |v| v.get())
            .clamp(1, 16);
        let mut workers = Vec::new();
        for _ in 0..count {
            if startup_cancel.load(Ordering::Relaxed) {
                break;
            }
            let (tx, cancel, work, query) =
                (tx.clone(), cancel.clone(), work.clone(), query.clone());
            workers.push(thread::spawn(move || loop {
                let dir = {
                    let (lock, cv) = &*work;
                    let mut state = lock.lock().unwrap();
                    loop {
                        if cancel.load(Ordering::Relaxed) || state.outstanding == 0 {
                            return;
                        }
                        if let Some(Reverse((_, _, _, _, _, dir))) = state.queue.pop() {
                            break dir;
                        }
                        state = cv.wait(state).unwrap();
                    }
                };
                if let Ok(entries) = fs::read_dir(dir) {
                    for item in entries.flatten() {
                        if cancel.load(Ordering::Relaxed) {
                            break;
                        }
                        let path = item.path();
                        let Ok(kind) = item.file_type() else { continue };
                        if kind.is_dir() && !kind.is_symlink() {
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
                        let name = item.file_name().to_string_lossy().into_owned();
                        if matches(&name, &query) {
                            let metadata = item.metadata().ok();
                            let mut entry = Entry {
                                path,
                                name,
                                size: metadata.as_ref().map(|m| m.len()),
                                modified: metadata.and_then(|m| m.modified().ok()),
                                is_dir: kind.is_dir(),
                            };
                            loop {
                                if cancel.load(Ordering::Relaxed) {
                                    return;
                                }
                                match tx.try_send(entry) {
                                    Ok(()) => break,
                                    Err(mpsc::TrySendError::Full(returned)) => {
                                        entry = returned;
                                        thread::sleep(std::time::Duration::from_millis(5));
                                    }
                                    Err(mpsc::TrySendError::Disconnected(_)) => return,
                                }
                            }
                        }
                    }
                }
                let (lock, cv) = &*work;
                let mut state = lock.lock().unwrap();
                state.outstanding -= 1;
                if state.outstanding == 0 {
                    cv.notify_all();
                }
            }));
        }
        let search = Self {
            receiver,
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
        self.receiver.try_recv()
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
mod tests {
    use super::*;
    fn private_temp_dir() -> tempfile::TempDir {
        #[cfg(unix)]
        let mut builder = tempfile::Builder::new();
        #[cfg(not(unix))]
        let builder = tempfile::Builder::new();
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            builder.permissions(std::fs::Permissions::from_mode(0o700));
        }
        builder.tempdir().unwrap()
    }
    #[test]
    fn matching() {
        assert!(matches("Project Nôtés.txt", "project notes"));
        assert!(!matches("Project Notes.txt", "projecx notes"));
        assert!(matches("Project Notes.txt", "fuzzy:projecx notes"));
        assert!(!matches("Project Notes.txt", "fuzzy:unrelated"));
        assert!(matches("diet", "fuzzy:tide"));
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
        let search = Search::start("match".into(), vec![root.to_path_buf()]);
        std::thread::sleep(std::time::Duration::from_millis(300));
        search.stop();
        let deadline = std::time::Instant::now() + std::time::Duration::from_secs(5);
        while !search.done() && std::time::Instant::now() < deadline {
            std::thread::yield_now();
        }
        assert!(search.done(), "cancelled search did not stop");
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
                Ok(e) => names.push(e.name),
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
