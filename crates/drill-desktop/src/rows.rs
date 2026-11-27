use crate::{result_date, result_order::exact_batch, search::Hit, DrillPathChar, DrillRow};
use drill_core::{Entry, MatchKind};
use std::cell::OnceCell;
use std::cmp::Ordering;
use std::ffi::CString;
use std::path::Path;
use std::ptr;

pub(super) fn text(value: String) -> CString {
    // Display text may be lossy. Action paths have their own native encoding.
    CString::new(value).unwrap_or_else(|error| {
        CString::new(String::from_utf8_lossy(&error.into_vec()).replace('\0', "�")).unwrap()
    })
}

struct Display {
    cells: [CString; 4],
    path: Vec<DrillPathChar>,
}

impl Display {
    fn new(entry: &Entry) -> Self {
        #[cfg(windows)]
        let path = {
            use std::os::windows::ffi::OsStrExt;
            entry
                .path
                .as_os_str()
                .encode_wide()
                .chain(Some(0))
                .collect()
        };
        #[cfg(unix)]
        let path = {
            use std::os::unix::ffi::OsStrExt;
            entry
                .path
                .as_os_str()
                .as_bytes()
                .iter()
                .map(|&b| b as DrillPathChar)
                .chain(Some(0))
                .collect()
        };
        Self {
            cells: [
                text(entry.name.clone()),
                text(
                    entry
                        .path
                        .parent()
                        .unwrap_or(Path::new(""))
                        .to_string_lossy()
                        .into_owned(),
                ),
                text(size_text(entry)),
                text(result_date::display(entry.modified)),
            ],
            path,
        }
    }
}

fn size_text(entry: &Entry) -> String {
    match entry.size {
        None => "?".into(),
        Some(0) if entry.is_dir => String::new(),
        Some(0) => "Empty".into(),
        Some(1..1024) => "1 KB".into(),
        Some(bytes) => {
            let mut value = bytes as f64 / 1024.0;
            for unit in ["KB", "MB", "GB", "TB", "PB"] {
                if value < 1024.0 {
                    return format!("{value:.0} {unit}");
                }
                value /= 1024.0;
            }
            format!("{value:.1} EB")
        }
    }
}

pub(super) struct Row {
    pub hit: Hit,
    display: OnceCell<Display>,
    folded_name: OnceCell<String>,
}

impl Row {
    pub fn native(&self) -> DrillRow {
        let display = self.display.get_or_init(|| Display::new(&self.hit.entry));
        DrillRow {
            cells: display.cells.each_ref().map(|s| s.as_ptr()),
            path: display.path.as_ptr(),
            directory: self.hit.entry.is_dir,
            registered_app: self.hit.desktop_id.is_some(),
            desktop_id: self
                .hit
                .desktop_id
                .as_ref()
                .map_or(ptr::null(), |s| s.as_ptr()),
        }
    }

    fn folded_name(&self) -> &str {
        self.folded_name
            .get_or_init(|| self.hit.entry.name.to_lowercase())
    }
}

#[derive(Copy, Clone, Eq, PartialEq)]
pub(super) enum Column {
    Name,
    Path,
    Size,
    Date,
}

#[derive(Copy, Clone)]
struct Sort {
    column: Column,
    ascending: bool,
}

impl Sort {
    fn compare(self, a: &Row, b: &Row) -> Ordering {
        let (x, y) = (&a.hit.entry, &b.hit.entry);
        let order = match self.column {
            Column::Name => a.folded_name().cmp(b.folded_name()),
            Column::Path => x.path.parent().cmp(&y.path.parent()),
            Column::Size => x.size.cmp(&y.size),
            Column::Date => x.modified.cmp(&y.modified),
        }
        .then_with(|| x.path.cmp(&y.path));
        if self.ascending {
            order
        } else {
            order.reverse()
        }
    }
}

// IDs index insertion order, while the separate small index array can be sorted
// or spliced without moving rows or making native table lookups linear.
pub(super) struct Rows {
    first_id: u64,
    entries: Vec<Row>,
    order: Vec<usize>,
    exact_count: usize,
    pub selected: Option<usize>,
    sort: Option<Sort>,
}

impl Rows {
    pub fn new() -> Self {
        Self {
            first_id: 1,
            entries: Vec::new(),
            order: Vec::new(),
            exact_count: 0,
            selected: None,
            sort: None,
        }
    }

    pub fn clear(&mut self) {
        self.first_id += self.entries.len() as u64;
        self.entries.clear();
        self.order.clear();
        self.exact_count = 0;
        self.selected = None;
    }

    pub fn len(&self) -> usize {
        self.order.len()
    }

    pub fn id(&self, index: usize) -> Option<u64> {
        self.order
            .get(index)
            .map(|&slot| self.first_id + slot as u64)
    }

    fn slot(&self, id: u64) -> Option<usize> {
        usize::try_from(id.checked_sub(self.first_id)?)
            .ok()
            .filter(|&slot| slot < self.entries.len())
    }

    pub fn get(&self, id: u64) -> Option<&Row> {
        self.entries.get(self.slot(id)?)
    }

    pub fn select(&mut self, id: u64) -> bool {
        let selection = self
            .slot(id)
            .and_then(|slot| self.order.iter().position(|&i| i == slot));
        if selection == self.selected {
            return false;
        }
        self.selected = selection;
        true
    }

    pub fn sort(&mut self, column: Column) {
        let sort = Sort {
            column,
            ascending: !self.sort.is_some_and(|s| s.column == column && s.ascending),
        };
        let selected = self.selected.map(|i| self.order[i]);
        self.order
            .sort_unstable_by(|&a, &b| sort.compare(&self.entries[a], &self.entries[b]));
        self.selected = selected.and_then(|slot| self.order.iter().position(|&i| i == slot));
        self.sort = Some(sort);
    }

    pub fn append(&mut self, batch: Vec<Hit>) {
        if batch.is_empty() {
            return;
        }
        let first = self.entries.len();
        self.entries.extend(batch.into_iter().map(|hit| Row {
            hit,
            display: OnceCell::new(),
            folded_name: OnceCell::new(),
        }));
        let indices = first..self.entries.len();
        if let Some(sort) = self.sort {
            let selected = self.selected.map(|i| self.order[i]);
            let mut incoming: Vec<_> = indices.collect();
            let cmp = |a: usize, b: usize| sort.compare(&self.entries[a], &self.entries[b]);
            incoming.sort_unstable_by(|&a, &b| cmp(a, b));
            let mut merged = Vec::with_capacity(self.order.len() + incoming.len());
            let mut old = self.order.as_slice();
            for index in incoming {
                let next = old.partition_point(|&i| !cmp(i, index).is_gt());
                merged.extend_from_slice(&old[..next]);
                merged.push(index);
                old = &old[next..];
            }
            merged.extend_from_slice(old);
            self.order = merged;
            self.selected = selected.and_then(|slot| self.order.iter().position(|&i| i == slot));
        } else {
            let (exact, partial): (Vec<_>, Vec<_>) =
                indices.partition(|&i| self.entries[i].hit.rank == MatchKind::Exact);
            let (range, selected) = exact_batch(self.exact_count, self.selected, exact.len());
            self.order.splice(range.start..range.start, exact);
            self.order.extend(partial);
            self.exact_count = range.end;
            self.selected = selected;
        }
    }
}

#[cfg(test)]
mod tests;
