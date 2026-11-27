use crate::icons::EmbeddedIcons;
use crate::rows::{text, Rows};
use crate::search::{Hit, Poll, Roots, Session};
use std::ffi::CString;
use std::path::PathBuf;
use std::time::{Duration, Instant};

const DEBOUNCE: Duration = Duration::from_millis(250);
const BATCH_SIZE: usize = 256;
const PAGE_SIZE: usize = 10_000;

enum Phase {
    Empty,
    Debouncing(Instant),
    Running(Session),
    Paused(Session, Hit),
    Stopped,
    Finished,
    Invalid(String),
}

pub(super) struct Model {
    roots: Roots,
    query: String,
    apps: bool,
    page_size: usize,
    limit: usize,
    phase: Phase,
    pub rows: Rows,
    pub status: CString,
    pub revision: u64,
    pub icons: EmbeddedIcons,
    pub icon_revision: u64,
}

impl Model {
    pub fn new(root: Option<PathBuf>) -> Self {
        Self::with_page_size(root, PAGE_SIZE)
    }

    pub fn with_page_size(root: Option<PathBuf>, page_size: usize) -> Self {
        Self {
            roots: Roots {
                explicit: root,
                #[cfg(target_os = "linux")]
                catalog: Default::default(),
            },
            query: String::new(),
            apps: false,
            page_size,
            limit: page_size,
            phase: Phase::Empty,
            rows: Rows::new(),
            status: c"Type to search".into(),
            revision: 1,
            icons: EmbeddedIcons::new(),
            icon_revision: 1,
        }
    }

    pub fn can_stop(&self) -> bool {
        matches!(
            self.phase,
            Phase::Debouncing(_) | Phase::Running(_) | Phase::Paused(..)
        )
    }

    pub fn can_continue(&self) -> bool {
        matches!(self.phase, Phase::Paused(..))
    }

    fn refresh_status(&mut self) {
        let n = self.rows.len();
        let count = format!("{n} {}", if n == 1 { "result" } else { "results" });
        self.status = text(match &self.phase {
            Phase::Empty => "Type to search".into(),
            Phase::Debouncing(_) | Phase::Running(_) => format!("Searching · {count}"),
            Phase::Paused(..) => format!("{count} · More results available"),
            Phase::Stopped => format!("Stopped · {count}"),
            Phase::Finished => count,
            Phase::Invalid(message) => message.clone(),
        });
        self.revision += 1;
    }

    pub fn query(&mut self, query: &str, apps: bool, now: Instant) {
        if self.query == query && self.apps == apps {
            return;
        }
        self.phase = if !apps && query.trim().is_empty() {
            Phase::Empty
        } else {
            Phase::Debouncing(now + DEBOUNCE)
        };
        self.rows.clear();
        self.icons.clear();
        self.icon_revision += 1;
        self.limit = self.page_size;
        #[cfg(target_os = "linux")]
        if self.apps && !apps {
            self.roots.catalog = Default::default();
        }
        self.query = query.to_owned();
        self.apps = apps;
        self.refresh_status();
    }

    pub fn stop(&mut self) {
        if self.can_stop() {
            self.phase = Phase::Stopped;
            self.refresh_status();
        }
    }

    pub fn resume(&mut self) {
        if !self.can_continue() {
            return;
        }
        let Phase::Paused(mut session, hit) = std::mem::replace(&mut self.phase, Phase::Finished)
        else {
            unreachable!()
        };
        self.limit = self.limit.saturating_add(self.page_size);
        self.rows.append(vec![hit]);
        session.set_paused(false);
        self.phase = Phase::Running(session);
        self.refresh_status();
    }

    pub fn tick(&mut self, now: Instant) {
        if self.icons.poll() {
            self.icon_revision += 1;
        }
        if matches!(self.phase, Phase::Debouncing(deadline) if now >= deadline) {
            self.phase = Phase::Running(Session::start(
                self.roots.clone(),
                self.query.clone(),
                self.apps,
            ));
        }
        let Phase::Running(session) = &mut self.phase else {
            return;
        };
        let mut batch = Vec::new();
        // Stop only when there is evidence of another page. Exactly 10,000
        // results must finish without an empty Continue action.
        let available = self.limit - self.rows.len();
        let mut extra = None;
        let mut terminal = None;
        for _ in 0..BATCH_SIZE {
            match session.next() {
                Poll::Hit(hit) if batch.len() == available => {
                    session.set_paused(true);
                    extra = Some(hit);
                    break;
                }
                Poll::Hit(hit) => batch.push(hit),
                Poll::Waiting => break,
                Poll::Finished => {
                    terminal = Some(Phase::Finished);
                    break;
                }
                Poll::Invalid(error) => {
                    terminal = Some(Phase::Invalid(error));
                    break;
                }
            }
        }
        if batch.is_empty() && extra.is_none() && terminal.is_none() {
            return;
        }
        self.rows.append(batch);
        if let Some(hit) = extra {
            let Phase::Running(session) = std::mem::replace(&mut self.phase, Phase::Finished)
            else {
                unreachable!()
            };
            self.phase = Phase::Paused(session, hit);
        } else if let Some(phase) = terminal {
            self.phase = phase;
        }
        self.refresh_status();
    }
}
