use super::*;
use std::time::{Duration, UNIX_EPOCH};

fn hit(rank: MatchKind, path: &str) -> Hit {
    let path = Path::new(path);
    (
        rank,
        Entry {
            path: path.to_owned(),
            name: path.file_name().unwrap().to_str().unwrap().to_owned(),
            size: None,
            modified: None,
            is_dir: false,
        },
    )
        .into()
}

fn names(rows: &Rows) -> Vec<&str> {
    (0..rows.len())
        .map(|index| {
            rows.get(rows.id(index).unwrap())
                .unwrap()
                .hit
                .entry
                .name
                .as_str()
        })
        .collect()
}

#[test]
fn streaming_exact_hits_preserve_rank_order_and_selected_identity() {
    use MatchKind::{Exact, Partial};
    for initial_selection in [None, Some(0), Some(1), Some(2)] {
        let mut rows = Rows::new();
        rows.append(vec![
            hit(Partial, "p1"),
            hit(Exact, "e1"),
            hit(Partial, "p2"),
        ]);
        assert_eq!(names(&rows), ["e1", "p1", "p2"]);
        let selected_id = initial_selection.and_then(|index| rows.id(index));
        if let Some(id) = selected_id {
            assert!(rows.select(id));
            assert!(!rows.select(id));
        }
        rows.append(vec![hit(Exact, "e2"), hit(Partial, "p3"), hit(Exact, "e3")]);
        rows.append(vec![hit(Partial, "p4")]);
        rows.append(vec![hit(Exact, "e4")]);
        assert_eq!(
            names(&rows),
            ["e1", "e2", "e3", "e4", "p1", "p2", "p3", "p4"]
        );
        assert_eq!(rows.selected.and_then(|index| rows.id(index)), selected_id);
    }
}

#[test]
fn sorted_batches_merge_at_the_front_middle_and_end_in_both_directions() {
    use MatchKind::{Exact, Partial};
    for ascending in [true, false] {
        let mut rows = Rows::new();
        rows.append(vec![hit(Exact, "Delta"), hit(Partial, "beta")]);
        let delta_id = rows.id(0).unwrap();
        rows.select(delta_id);
        rows.sort(Column::Name);
        if !ascending {
            rows.sort(Column::Name);
        }
        rows.append(vec![
            hit(Partial, "Zulu"),
            hit(Exact, "alpha"),
            hit(Partial, "CHARLIE"),
        ]);
        rows.append(vec![hit(Exact, "echo"), hit(Partial, "bravo")]);
        let mut ordered = ["alpha", "beta", "bravo", "CHARLIE", "Delta", "echo", "Zulu"];
        if !ascending {
            ordered.reverse();
        }
        assert_eq!(names(&rows), ordered);
        assert_eq!(rows.selected.and_then(|i| rows.id(i)), Some(delta_id));
    }
}

#[test]
fn column_sorts_use_native_paths_numeric_values_and_precise_dates() {
    // The two Echo entries share folded names, size and date, so each sort must
    // resolve that tie by full path. A parent path still precedes its subdirectory.
    let early = UNIX_EPOCH;
    let late = UNIX_EPOCH + Duration::from_nanos(1);
    let mut rows = Rows::new();
    for (path, size, modified) in [
        ("a/z", None, Some(early)),
        ("a/k/Echo", Some(2), Some(late)),
        ("b/echo", Some(2), Some(late)),
        ("b/alpha", Some(11), None),
    ] {
        let mut result = hit(MatchKind::Partial, path);
        result.entry.size = size;
        result.entry.modified = modified;
        rows.append(vec![result]);
    }
    let id = rows.id(2).unwrap();
    assert!(rows.select(id));
    for (column, mut order) in [
        (Column::Name, ["alpha", "Echo", "echo", "z"]),
        (Column::Path, ["z", "Echo", "alpha", "echo"]),
        (Column::Size, ["z", "Echo", "echo", "alpha"]),
        (Column::Date, ["alpha", "z", "Echo", "echo"]),
    ] {
        rows.sort(column);
        assert_eq!(names(&rows), order);
        assert_eq!(rows.selected.and_then(|i| rows.id(i)), Some(id));
        rows.sort(column);
        order.reverse();
        assert_eq!(names(&rows), order);
        assert_eq!(rows.selected.and_then(|i| rows.id(i)), Some(id));
    }
    assert!(rows.select(0));
    assert!(rows.selected.is_none());
}

#[test]
fn replacing_results_invalidates_all_old_ids_and_preserves_sort() {
    let mut rows = Rows::new();
    rows.append(vec![
        hit(MatchKind::Partial, "z"),
        hit(MatchKind::Exact, "a"),
    ]);
    let ids = [rows.id(0).unwrap(), rows.id(1).unwrap()];
    rows.sort(Column::Name);
    rows.select(ids[1]);
    rows.clear();
    assert_eq!(rows.len(), 0);
    assert!(rows.selected.is_none());
    assert!(rows.id(0).is_none());
    rows.append(vec![
        hit(MatchKind::Exact, "z"),
        hit(MatchKind::Partial, "a"),
    ]);
    assert_eq!(names(&rows), ["a", "z"]);
    for stale in ids {
        assert!(rows.get(stale).is_none());
        assert!(!rows.select(stale));
    }
    assert!(rows.get(0).is_none());
    assert!(rows.get(u64::MAX).is_none());
    assert!(rows.id(rows.len()).is_none());
}

#[test]
fn sizes_cover_empty_files_directories_unknown_metadata_and_unit_boundaries() {
    let mut entry = hit(MatchKind::Partial, "sample").entry;
    for (bytes, is_dir, label) in [
        (None, true, "?"),
        (Some(0), true, ""),
        (Some(0), false, "Empty"),
        (Some(1), false, "1 KB"),
        (Some(1023), false, "1 KB"),
        (Some(1024), false, "1 KB"),
        (Some(1536), false, "2 KB"),
        (Some(1 << 20), false, "1 MB"),
        (Some(1 << 30), false, "1 GB"),
        (Some(1 << 40), false, "1 TB"),
        (Some(1 << 50), false, "1 PB"),
        (Some(1 << 60), false, "1.0 EB"),
    ] {
        entry.size = bytes;
        entry.is_dir = is_dir;
        assert_eq!(size_text(&entry), label);
    }
}
