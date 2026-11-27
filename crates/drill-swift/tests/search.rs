#![cfg(unix)]
#![deny(unsafe_op_in_unsafe_fn)]

use drill_swift::*;
use std::collections::HashSet;
use std::ffi::{c_char, c_void, CStr, CString, OsStr};
use std::fs;
use std::os::unix::ffi::OsStrExt;
use std::path::{Path, PathBuf};
use std::time::{Duration, Instant};

#[path = "../../drill-core/src/test_directory.rs"]
mod test_directory;
use test_directory::private_temp_dir;

#[derive(Debug)]
struct Hit {
    path: PathBuf,
    name: String,
    rank: u8,
    is_dir: bool,
    size: u64,
    modified: i64,
    nanos: u32,
}

unsafe extern "C" fn receive(
    ctx: *mut c_void,
    path: *const u8,
    path_len: usize,
    name: *const c_char,
    rank: u8,
    is_dir: bool,
    size: u64,
    modified: i64,
    nanos: u32,
) {
    // SAFETY: poll passed an exclusive borrow of this Vec as its context.
    let hits = unsafe { &mut *ctx.cast::<Vec<Hit>>() };
    // SAFETY: the callback ABI lends exactly path_len contiguous path bytes.
    let path = unsafe { std::slice::from_raw_parts(path, path_len) };
    // SAFETY: the callback ABI lends a NUL-terminated name until we return.
    let name = unsafe { CStr::from_ptr(name) };
    hits.push(Hit {
        path: OsStr::from_bytes(path).into(),
        name: name.to_string_lossy().into_owned(),
        rank,
        is_dir,
        size,
        modified,
        nanos,
    });
}

struct Handle(*mut DrillSearch);

impl Handle {
    fn new(query: &str, apps: bool, root: &Path) -> Self {
        let root = root.as_os_str().as_bytes();
        let query = CString::new(query).unwrap();
        // SAFETY: the CString and entire root slice stay live through startup's copy.
        Self(unsafe { drill_search_start(query.as_ptr(), apps, root.as_ptr(), root.len()) })
    }

    fn with_additional(query: &str, apps: bool, root: &Path, additional: &[u8]) -> Self {
        let root = root.as_os_str().as_bytes();
        let query = CString::new(query).unwrap();
        // SAFETY: the C string and both borrowed buffers outlive this call.
        Self(unsafe {
            drill_search_start_with_roots(
                query.as_ptr(),
                apps,
                root.as_ptr(),
                root.len(),
                additional.as_ptr(),
                additional.len(),
            )
        })
    }

    #[cfg(target_os = "macos")]
    fn with_options(
        query: &str,
        apps: bool,
        root: &Path,
        additional: &[u8],
        search_inside_photos_libraries: bool,
    ) -> Self {
        let root = root.as_os_str().as_bytes();
        let query = CString::new(query).unwrap();
        // SAFETY: the C string and both borrowed buffers outlive this call.
        Self(unsafe {
            drill_search_start_with_options(
                query.as_ptr(),
                apps,
                root.as_ptr(),
                root.len(),
                additional.as_ptr(),
                additional.len(),
                search_inside_photos_libraries,
            )
        })
    }

    fn poll(&mut self, limit: u32, hits: &mut Vec<Hit>) -> bool {
        let before = hits.len();
        // SAFETY: self owns the live handle, and receive accesses hits only
        // synchronously, using the exclusive borrow passed here.
        let complete = unsafe {
            drill_search_poll(
                self.0,
                limit,
                std::ptr::from_mut(hits).cast(),
                Some(receive),
            )
        };
        assert!(hits.len() - before <= limit.min(256) as usize);
        complete == 1
    }

    fn drain(&mut self, limit: u32) -> Vec<Hit> {
        let deadline = Instant::now() + Duration::from_secs(10);
        let mut hits = Vec::new();
        while !self.poll(limit, &mut hits) {
            assert!(Instant::now() < deadline, "search timed out");
            std::thread::sleep(Duration::from_millis(1));
        }
        hits
    }

    #[cfg(target_os = "macos")]
    fn sorted_paths(mut self) -> Vec<PathBuf> {
        let mut paths: Vec<_> = self.drain(1).into_iter().map(|hit| hit.path).collect();
        assert_eq!(self.error(), None);
        paths.sort();
        paths
    }

    fn error(&self) -> Option<String> {
        // SAFETY: this live handle stays immutably borrowed while copying the error.
        let error = unsafe { drill_search_error(self.0) };
        (!error.is_null()).then(|| {
            // SAFETY: a non-null error is a NUL-terminated string owned by the handle.
            unsafe { CStr::from_ptr(error) }
                .to_str()
                .unwrap()
                .to_owned()
        })
    }

    fn pause(&mut self, paused: bool) {
        // SAFETY: this mutable borrow gives exclusive access to the live handle.
        unsafe { drill_search_set_paused(self.0, paused) }
    }
}

impl Drop for Handle {
    fn drop(&mut self) {
        // SAFETY: Handle uniquely owns this allocation from the startup ABI.
        unsafe { drill_search_free(self.0) }
    }
}

#[test]
fn additional_roots_are_copied_and_combined_with_the_original_scan() {
    let dir = private_temp_dir();
    let base = dir.path().join("base");
    let extra = dir.path().join("selected\nfolder");
    let nested = extra.join("nested");
    fs::create_dir(&base).unwrap();
    fs::create_dir_all(&nested).unwrap();
    let expected = [base.join("shared-a.app"), nested.join("shared-b.app")];
    for path in &expected {
        fs::create_dir(path).unwrap();
    }
    let file = extra.join("shared.txt");
    fs::write(&file, []).unwrap();
    // Duplicate and overlapping roots must not duplicate the matching files.
    let mut paths = Vec::new();
    for path in [&extra, &nested, &extra, &base] {
        paths.extend_from_slice(path.as_os_str().as_bytes());
        paths.push(0);
    }
    let mut cancelled = Handle::with_additional("shared", false, &base, &paths);
    cancelled.pause(true);
    drop(cancelled);

    let mut apps = Handle::with_additional("shared", true, &base, &paths);
    let mut files = Handle::with_additional("shared", false, &base, &paths);
    paths.fill(0); // The asynchronous workers must already own both inputs.
    let mut app_hits: Vec<_> = apps.drain(1).into_iter().map(|hit| hit.path).collect();
    app_hits.sort();
    assert_eq!(app_hits, expected);
    let mut file_hits: Vec<_> = files.drain(2).into_iter().map(|hit| hit.path).collect();
    file_hits.sort();
    let mut expected_files = Vec::from(expected);
    expected_files.push(file);
    expected_files.sort();
    assert_eq!(file_hits, expected_files);
}

#[test]
fn malformed_additional_roots_report_an_error_before_startup() {
    let dir = private_temp_dir();
    for malformed in [b"/unterminated".as_slice(), b"/a\0\0", b"relative\0"] {
        let mut search = Handle::with_additional("x", false, dir.path(), malformed);
        assert!(search.error().is_some());
        assert!(search.drain(10).is_empty());
    }
}

#[test]
fn streams_original_path_bytes_alongside_utf8_display_name_and_metadata() {
    let dir = private_temp_dir();
    // APFS rejects malformed UTF-8. Linux can also exercise distinct path
    // bytes that collapse to the same display name from a real filesystem.
    #[cfg(target_os = "linux")]
    let (root_name, names): (&[u8], [&[u8]; 2]) = (b"root-\xff", [b"x\xfd", b"x\xfe"]);
    #[cfg(not(target_os = "linux"))]
    let (root_name, names): (&[u8], [&[u8]; 2]) = ("røøt".as_bytes(), [b"x\n", "xß".as_bytes()]);
    let root = dir.path().join(OsStr::from_bytes(root_name));
    fs::create_dir(&root).unwrap();
    for name in names {
        fs::write(root.join(OsStr::from_bytes(name)), b"abc").unwrap();
    }
    let mut search = Handle::new("regex:^x", false, &root);
    let hits = search.drain(1);
    assert_eq!(search.error(), None);
    assert_eq!(hits.len(), 2);
    assert_ne!(hits[0].path, hits[1].path);
    for hit in hits {
        assert_eq!(hit.name, hit.path.file_name().unwrap().to_string_lossy());
        let modified = fs::metadata(&hit.path)
            .unwrap()
            .modified()
            .unwrap()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap();
        assert_eq!(fs::read(hit.path).unwrap(), b"abc");
        assert_eq!(hit.rank, 1);
        assert!(!hit.is_dir);
        assert_eq!(hit.size, 3);
        assert_eq!(
            (hit.modified, hit.nanos),
            (modified.as_secs() as i64, modified.subsec_nanos())
        );
    }
}

#[test]
fn apps_use_core_bundle_filter_stem_ranking_and_empty_query_behavior() {
    let dir = private_temp_dir();
    let root = dir.path();
    fs::create_dir_all(root.join("Notes.app/Notes Inside.app")).unwrap();
    fs::create_dir(root.join("Notes Pro.APP")).unwrap();
    fs::write(root.join("Notes.txt"), []).unwrap();
    fs::write(root.join("Notes Other.app"), []).unwrap();
    let mut hits = Handle::new("notes", true, root).drain(2);
    hits.sort_by_key(|hit| hit.rank);
    assert_eq!(hits.len(), 2);
    assert_eq!((&*hits[0].name, hits[0].rank), ("Notes.app", 0));
    assert_eq!((&*hits[1].name, hits[1].rank), ("Notes Pro.APP", 1));
    assert!(hits.iter().all(|hit| hit.is_dir));
    assert_eq!(Handle::new(" ", true, root).drain(2).len(), 2);
    assert!(Handle::new(" ", false, root).drain(2).is_empty());
    assert!(Handle::new("fuzzy:", true, root).drain(2).is_empty());
}

#[cfg(target_os = "macos")]
#[test]
fn photos_library_option_controls_parent_searches_in_both_scopes() {
    let dir = private_temp_dir();
    let root = dir.path();
    let library = root.join("Sample.PHOTOSLIBRARY");
    let originals = library.join("originals");
    let photo = originals.join("Sample Original.jpg");
    let app = originals.join("Sample Internal.app");
    let loose = root.join("Sample.photoslibrary-backup");
    let loose_photo = loose.join("Sample Loose.jpg");
    let loose_app = loose.join("Sample Tools.app");
    fs::create_dir_all(&app).unwrap();
    fs::create_dir_all(&loose_app).unwrap();
    fs::write(&photo, []).unwrap();
    fs::write(&loose_photo, []).unwrap();

    let search =
        |apps, enabled| Handle::with_options("sample", apps, root, &[], enabled).sorted_paths();
    let outside_files = vec![library, loose, loose_photo, loose_app.clone()];
    let outside_apps = std::slice::from_ref(&loose_app);
    assert_eq!(
        Handle::new("sample", false, root).sorted_paths(),
        outside_files
    );
    assert_eq!(
        Handle::new("sample", true, root).sorted_paths(),
        outside_apps
    );
    assert_eq!(search(false, false), outside_files);
    assert_eq!(search(true, false), outside_apps);

    let mut all_files = outside_files;
    all_files.extend([photo, app.clone()]);
    all_files.sort();
    assert_eq!(search(false, true), all_files);
    assert_eq!(search(true, true), [app, loose_app]);
}

#[cfg(target_os = "macos")]
#[test]
fn explicit_photos_library_roots_search_contents_without_duplicate_hits() {
    let dir = private_temp_dir();
    let root = dir.path();
    let library = root.join("Sample.photoslibrary");
    let originals = library.join("originals");
    let photo = originals.join("Sample Original.jpg");
    let app = originals.join("Sample Internal.app");
    fs::create_dir_all(&app).unwrap();
    fs::write(&photo, []).unwrap();

    for selected in [&library, &originals] {
        let paths = Handle::new("sample", false, selected).sorted_paths();
        assert_eq!(paths, [app.clone(), photo.clone()]);
        let paths = Handle::new("sample", true, selected).sorted_paths();
        assert_eq!(paths, std::slice::from_ref(&app));
    }

    let mut additional = Vec::new();
    for selected in [&originals, &library, &originals] {
        additional.extend_from_slice(selected.as_os_str().as_bytes());
        additional.push(0);
    }
    let expected_files = [library, app.clone(), photo];
    for enabled in [false, true] {
        let files = Handle::with_options("sample", false, root, &additional, enabled);
        assert_eq!(files.sorted_paths(), expected_files);
        let apps = Handle::with_options("sample", true, root, &additional, enabled);
        assert_eq!(apps.sorted_paths(), std::slice::from_ref(&app));
    }
}

#[test]
fn paused_search_resumes_and_drains_more_than_one_full_core_queue() {
    let dir = private_temp_dir();
    let root = dir.path();
    for n in 0..730 {
        fs::write(root.join(format!("match-{n}")), []).unwrap();
    }
    let mut search = Handle::new("match", false, root);
    search.pause(true);
    let mut hits = vec![];
    assert!(!search.poll(256, &mut hits));
    assert!(hits.is_empty());
    search.pause(false);
    let deadline = Instant::now() + Duration::from_secs(10);
    while hits.is_empty() {
        assert!(!search.poll(1, &mut hits));
        assert!(Instant::now() < deadline);
        std::thread::sleep(Duration::from_millis(1));
    }
    search.pause(true);
    assert!(!search.poll(u32::MAX, &mut hits));
    assert_eq!(hits.len(), 1);
    search.pause(false);
    hits.extend(search.drain(u32::MAX));
    assert_eq!(hits.len(), 730);
    assert_eq!(
        hits.into_iter()
            .map(|hit| hit.path)
            .collect::<HashSet<_>>()
            .len(),
        730
    );
}

#[test]
fn invalid_queries_and_invalid_root_arguments_report_errors() {
    let dir = private_temp_dir();
    let mut search = Handle::new("regex:(", false, dir.path());
    assert!(search.drain(10).is_empty());
    assert!(search.error().unwrap().starts_with("Invalid regex:"));
    for (root, len) in [
        (std::ptr::null(), 5),
        (b"a\0b".as_ptr(), 3),
        (b"/".as_ptr(), usize::MAX),
    ] {
        // SAFETY: the ABI rejects null or oversized root inputs before reading;
        // the remaining length describes a live byte string.
        let mut search = Handle(unsafe { drill_search_start(c"x".as_ptr(), false, root, len) });
        assert!(search.error().is_some());
        assert!(search.drain(10).is_empty());
    }
}
