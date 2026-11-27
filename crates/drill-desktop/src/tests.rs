use super::*;
use std::ffi::CString;
use std::fs;
use std::mem::MaybeUninit;
use std::time::Duration;

fn start(model: &mut Model, query: &str, apps: bool) {
    let query = CString::new(query).unwrap();
    // SAFETY: the query buffer remains valid for this call.
    unsafe { drill_query(model, query.as_ptr(), apps) };
    model.tick(Instant::now() + Duration::from_millis(251));
}

fn settled(model: &mut Model) -> DrillState {
    let deadline = Instant::now() + Duration::from_secs(10);
    loop {
        let state = drill_tick(model);
        if !state.can_stop || state.can_continue {
            return state;
        }
        assert!(Instant::now() < deadline, "search did not settle");
        std::thread::sleep(Duration::from_millis(1));
    }
}

fn native_row(model: &Model, id: u64) -> DrillRow {
    let mut row = MaybeUninit::uninit();
    // SAFETY: drill_row initializes the entire output on success.
    unsafe {
        assert!(drill_row(model, id, row.as_mut_ptr()));
        row.assume_init()
    }
}

fn name(model: &Model, index: usize) -> String {
    let row = native_row(model, drill_row_id(model, index));
    // SAFETY: the model is still borrowed and no mutation has occurred.
    unsafe { CStr::from_ptr(row.cells[0]) }
        .to_str()
        .unwrap()
        .into()
}

#[test]
fn replacing_queries_debounces_and_drops_obsolete_rows_and_selection() {
    let root = test_directory::private_temp_dir();
    fs::write(root.path().join("report"), b"").unwrap();
    fs::write(root.path().join("reporter"), b"").unwrap();
    let mut model = Model::new(Some(root.path().to_owned()));
    let now = Instant::now();
    model.query("report", false, now);
    model.tick(now + Duration::from_millis(249));
    assert_eq!(model.rows.len(), 0);
    assert_eq!(model.status.to_str().unwrap(), "Searching · 0 results");
    model.tick(now + Duration::from_millis(250));
    assert_eq!(settled(&mut model).count, 2);
    assert_eq!(name(&model, 0), "report");
    let old = drill_row_id(&model, 0);
    drill_select(&mut model, old);
    assert_eq!(drill_tick(&mut model).selected_index, 0);
    start(&mut model, "regex:[", false);
    assert_eq!(model.rows.len(), 0);
    assert_eq!(drill_tick(&mut model).selected_index, -1);
    let state = settled(&mut model);
    assert!(!state.can_stop);
    assert!(model.status.to_str().unwrap().starts_with("Invalid regex"));
    assert_eq!(drill_row_id(&model, 0), 0);
    start(&mut model, "report", false);
    settled(&mut model);
    assert_ne!(drill_row_id(&model, 0), old);
    assert!(model.rows.get(old).is_none());
    start(&mut model, "  ", false);
    assert_eq!(model.status.to_str().unwrap(), "Type to search");
    assert!(!model.can_stop());
}

#[test]
fn pagination_uses_one_lookahead_and_continues_the_original_session() {
    let root = test_directory::private_temp_dir();
    let mut model = Model::with_page_size(Some(root.path().to_owned()), 2);
    for file in ["a.file", "b.file"] {
        fs::write(root.path().join(file), b"").unwrap();
    }
    start(&mut model, "file", false);
    assert!(!settled(&mut model).can_continue);
    for file in ["c.file", "d.file", "e.file"] {
        fs::write(root.path().join(file), b"").unwrap();
    }
    start(&mut model, "glob:*.file", false);
    let state = settled(&mut model);
    assert!(state.can_continue && state.can_stop);
    assert_eq!(state.count, 2);
    assert_eq!(
        model.status.to_str().unwrap(),
        "2 results · More results available"
    );
    let selected = drill_row_id(&model, 1);
    drill_select(&mut model, selected);
    drill_sort(&mut model, 0);
    drill_continue(&mut model);
    assert!(settled(&mut model).can_continue);
    assert_eq!(model.rows.len(), 4);
    drill_continue(&mut model);
    assert!(!settled(&mut model).can_stop);
    assert_eq!(drill_row_id(&model, model.rows.selected.unwrap()), selected);
    assert_eq!(
        (0..5).map(|i| name(&model, i)).collect::<Vec<_>>(),
        ["a.file", "b.file", "c.file", "d.file", "e.file"]
    );
    assert_eq!(model.status.to_str().unwrap(), "5 results");

    start(&mut model, "file", false);
    assert!(settled(&mut model).can_continue);
    drill_stop(&mut model);
    drill_continue(&mut model);
    assert!(!drill_tick(&mut model).can_continue);
    assert_eq!(model.status.to_str().unwrap(), "Stopped · 2 results");
}

#[cfg(unix)]
#[test]
fn lossy_display_names_retain_distinct_original_action_paths() {
    use std::os::unix::ffi::OsStrExt;
    let root = test_directory::private_temp_dir();
    let paths: Vec<_> = [b"doc-\xff" as &[u8], b"doc-\xfe"]
        .iter()
        .map(|b| root.path().join(std::ffi::OsStr::from_bytes(b)))
        .collect();
    let mut model = Model::new(Some(root.path().to_owned()));
    #[cfg(target_os = "linux")]
    {
        for path in &paths {
            fs::write(path, b"").unwrap();
        }
        start(&mut model, "doc-", false);
        assert_eq!(settled(&mut model).count, 2);
    }
    #[cfg(target_os = "macos")]
    {
        // APFS rejects these byte sequences on creation. Exercise the same
        // table boundary with paths supplied by a synthetic Unix mount.
        model.rows.append(
            paths
                .iter()
                .map(|path| {
                    (
                        drill_core::MatchKind::Partial,
                        drill_core::Entry {
                            path: path.clone(),
                            name: path.file_name().unwrap().to_string_lossy().into_owned(),
                            size: Some(0),
                            modified: None,
                            is_dir: false,
                        },
                    )
                        .into()
                })
                .collect(),
        );
    }
    assert_eq!(name(&model, 0), name(&model, 1));
    let actual: std::collections::HashSet<_> = (0..2)
        .map(|i| {
            let item = native_row(&model, drill_row_id(&model, i));
            assert!(!item.registered_app && item.desktop_id.is_null());
            // SAFETY: the borrowed pointer is the model's NUL-terminated Unix path.
            unsafe { CStr::from_ptr(item.path) }.to_bytes().to_vec()
        })
        .collect();
    for path in paths {
        assert!(actual.contains(path.as_os_str().as_bytes()));
    }
}

#[cfg(windows)]
#[test]
fn explicit_windows_apps_root_emits_only_executables() {
    use std::os::windows::ffi::OsStrExt;
    let root = test_directory::private_temp_dir();
    let exe = root.path().join("Tést.ExE");
    fs::write(&exe, b"exe").unwrap();
    fs::write(root.path().join("note.txt"), b"text").unwrap();
    fs::create_dir(root.path().join("folder.exe")).unwrap();
    let mut model = Model::new(Some(root.path().to_owned()));
    start(&mut model, "", true);
    assert_eq!(settled(&mut model).count, 1);
    let row = native_row(&model, drill_row_id(&model, 0));
    assert!(!row.registered_app && !row.directory);
    let expected = exe
        .as_os_str()
        .encode_wide()
        .chain(Some(0))
        .collect::<Vec<_>>();
    for (index, unit) in expected.into_iter().enumerate() {
        // SAFETY: the model owns a terminated path. A premature terminator
        // fails this assertion before the next unit can be read.
        let actual = unsafe { *row.path.add(index) };
        assert_eq!(actual, unit);
    }
}
