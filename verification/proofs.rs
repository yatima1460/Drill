#![cfg(kani)]

// These are the modules used by the search worker, desktop UI and Wasm guest.
#[path = "../tools/appimage-icon-wasm/src/bounds.rs"]
mod appimage_bounds;
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
fn late_exact_hits_preserve_row_coordinates() {
    let old_len: usize = kani::any();
    let boundary: usize = kani::any();
    let added: usize = kani::any();
    let selected: Option<usize> = kani::any();
    kani::assume(boundary <= old_len && added <= usize::MAX - old_len);
    kani::assume(selected.is_none_or(|i| i < old_len));
    let (inserted, after) = result_order::exact_batch(boundary, selected, added);

    assert_eq!(inserted.start, boundary);
    assert_eq!(inserted.end, boundary + added);
    assert_eq!(inserted.len(), added);
    assert!(inserted.end <= old_len + added);
    if let Some(i) = after {
        assert!(i < old_len + added);
        assert!(!inserted.contains(&i));
        // Reverse the insertion. The decoded old row index is the original selection.
        let original = if i < inserted.start { i } else { i - added };
        assert_eq!(Some(original), selected);
    } else {
        assert!(selected.is_none());
    }
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

#[kani::proof]
fn appimage_archive_reads_fit_the_selected_file() {
    let start: u64 = kani::any();
    let file_len: u64 = kani::any();
    let relative: u64 = kani::any();
    let size: u64 = kani::any();
    let absolute = u128::from(start) + u128::from(relative);
    let fits = absolute + u128::from(size) <= u128::from(file_len);
    let result = appimage_bounds::file_offset(start, file_len, relative, size);
    assert_eq!(result.is_some(), fits);
    if let Some(pos) = result {
        assert_eq!(u128::from(pos), absolute);
    }
}
