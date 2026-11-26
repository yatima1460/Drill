/// Translate a read relative to the SquashFS start into the selected file.
pub(super) fn file_offset(
    region_start: u64,
    file_len: u64,
    relative: u64,
    size: u64,
) -> Option<u64> {
    let absolute = region_start.checked_add(relative)?;
    let remaining = file_len.checked_sub(absolute)?;
    (size <= remaining).then_some(absolute)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn allows_eof_and_rejects_out_of_range_and_overflowing_reads() {
        assert_eq!(file_offset(10, 17, 3, 4), Some(13));
        assert_eq!(file_offset(10, 17, 7, 0), Some(17));
        assert_eq!(file_offset(10, 17, 3, 5), None);
        assert_eq!(file_offset(10, 9, 0, 0), None);
        assert_eq!(file_offset(u64::MAX, u64::MAX, 1, 0), None);
        assert_eq!(file_offset(1, u64::MAX, 0, u64::MAX), None);
    }
}
