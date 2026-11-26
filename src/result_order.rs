use std::ops::Range;

/// New exact hits occupy this range immediately before the old partial hits.
/// The caller splices at its start and keeps its end as the new exact prefix.
pub(super) fn exact_batch(
    boundary: usize,
    selected: Option<usize>,
    count: usize,
) -> (Range<usize>, Option<usize>) {
    let selected = selected.map(|i| if i >= boundary { i + count } else { i });
    (boundary..boundary + count, selected)
}
