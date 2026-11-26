use std::ops::Range;

/// Convert PE resource coordinates into a range inside the guest's wasm32 input.
pub(super) fn byte_range(offset: u64, size: u32, input_len: u32) -> Option<Range<usize>> {
    let start = u32::try_from(offset).ok()?;
    let end = start.checked_add(size)?;
    (end <= input_len).then_some(start as usize..end as usize)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn range_may_end_at_eof_but_cannot_wrap_or_extend_past_it() {
        assert_eq!(byte_range(4, 3, 7), Some(4..7));
        assert_eq!(byte_range(7, 0, 7), Some(7..7));
        assert_eq!(byte_range(4, 4, 7), None);
        assert_eq!(byte_range(u32::MAX as u64, 1, u32::MAX), None);
        assert_eq!(byte_range(1 << 32, 0, u32::MAX), None);
    }
}
