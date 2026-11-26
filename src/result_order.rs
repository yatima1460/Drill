/// Insert new exact hits after older exact hits, keeping the selected row's identity.
pub(super) fn insert_exact<T>(
    rows: &mut Vec<T>,
    exact_count: &mut usize,
    selected: &mut Option<usize>,
    exact: Vec<T>,
) {
    if exact.is_empty() {
        return;
    }
    let boundary = *exact_count;
    if let Some(index) = selected {
        if *index >= boundary {
            *index += exact.len();
        }
    }
    *exact_count += exact.len();
    rows.splice(boundary..boundary, exact);
}
