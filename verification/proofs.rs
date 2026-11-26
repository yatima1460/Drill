#![cfg(kani)]

// These are the modules used by the search worker, desktop UI and Wasm guest.
#[path = "../crates/drill-core/src/file_filter.rs"]
mod file_filter;
#[path = "../tools/exe-icon-wasm/src/resource.rs"]
mod resource;
#[path = "../src/result_order.rs"]
mod result_order;

#[kani::proof]
#[kani::unwind(6)]
fn app_filters_require_the_right_kind_and_complete_extension() {
    use file_filter::FileFilter;
    use std::ffi::OsStr;
    use std::os::unix::ffi::OsStrExt;

    let bytes: [u8; 4] = kani::any();
    let len: usize = kani::any();
    kani::assume(len <= bytes.len());
    let ext = OsStr::from_bytes(&bytes[..len]);
    // A filesystem entry can be a directory, a regular file, or neither.
    let is_dir: bool = kani::any();
    let is_file = !is_dir && kani::any();

    let app = matches!(bytes, [b'A' | b'a', b'P' | b'p', b'P' | b'p', _]) && len == 3;
    let exe = matches!(bytes, [b'E' | b'e', b'X' | b'x', b'E' | b'e', _]) && len == 3;
    assert!(FileFilter::All.accepts_extension(ext, is_dir, is_file));
    assert_eq!(
        FileFilter::MacBundles.accepts_extension(ext, is_dir, is_file),
        is_dir && app
    );
    assert_eq!(
        FileFilter::WindowsExecutables.accepts_extension(ext, is_dir, is_file),
        is_file && exe
    );
}

#[kani::proof]
#[kani::unwind(10)]
fn late_exact_hits_preserve_order_and_selection() {
    // Distinct row IDs make deletion, duplication and wrong selection observable.
    let old_len: usize = kani::any();
    let added: usize = kani::any();
    let boundary: usize = kani::any();
    kani::assume(old_len <= 3 && added <= 2 && boundary <= old_len);
    let selected: Option<usize> = kani::any();
    kani::assume(selected.is_none_or(|i| i < old_len));

    let mut rows = vec![0u8, 1, 2];
    rows.truncate(old_len);
    let mut exact = vec![3u8, 4];
    exact.truncate(added);
    let mut exact_count = boundary;
    let mut new_selection = selected;
    result_order::insert_exact(&mut rows, &mut exact_count, &mut new_selection, exact);

    assert_eq!(rows.len(), old_len + added);
    assert_eq!(exact_count, boundary + added);
    for (i, id) in rows.iter().enumerate() {
        if i < boundary {
            assert_eq!(usize::from(*id), i);
        } else if i < exact_count {
            assert_eq!(usize::from(*id), 3 + (i - boundary));
        } else {
            assert_eq!(usize::from(*id), i - added);
        }
    }
    assert_eq!(new_selection.map(|i| usize::from(rows[i])), selected);
}

#[kani::proof]
fn pe_resource_range_is_exact_and_inside_wasm32_input() {
    let offset: u64 = kani::any();
    let size: u32 = kani::any();
    let input_len: u32 = kani::any();
    // Wider arithmetic specifies the mathematical endpoint without wrapping.
    let end = u128::from(offset) + u128::from(size);
    let range = resource::byte_range(offset, size, input_len);
    assert_eq!(range.is_some(), end <= u128::from(input_len));
    if let Some(range) = range {
        assert_eq!(range.start as u128, u128::from(offset));
        assert_eq!(range.end as u128, end);
        assert_eq!(range.len() as u128, u128::from(size));
    }
}
