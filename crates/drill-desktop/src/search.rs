use drill_core::{Entry, FileFilter, MatchKind, Search, SearchQuery};
use std::ffi::CString;
use std::path::PathBuf;
use std::sync::{
    atomic::{AtomicBool, Ordering},
    mpsc::{self, TryRecvError},
    Arc,
};

#[cfg(target_os = "linux")]
use crate::linux_apps::Catalog;
#[cfg(target_os = "linux")]
use std::sync::OnceLock;

pub(super) struct Hit {
    pub rank: MatchKind,
    pub entry: Entry,
    pub desktop_id: Option<CString>,
}

impl From<(MatchKind, Entry)> for Hit {
    fn from((rank, entry): (MatchKind, Entry)) -> Self {
        Self {
            rank,
            entry,
            desktop_id: None,
        }
    }
}

#[derive(Default, Clone)]
pub(super) struct Roots {
    pub explicit: Option<PathBuf>,
    #[cfg(target_os = "linux")]
    pub catalog: Arc<OnceLock<Catalog>>,
}

enum Results {
    Walk(Search),
    #[cfg(windows)]
    Windows(drill_core::WindowsSearch),
    #[cfg(target_os = "linux")]
    Apps(std::vec::IntoIter<Hit>),
}

impl Results {
    fn start(roots: Roots, query: SearchQuery, apps: bool, cancel: Arc<AtomicBool>) -> Self {
        #[cfg(target_os = "linux")]
        if apps {
            let hits = roots
                .catalog
                .get_or_init(Catalog::load)
                .search(&query, &cancel);
            return Self::Apps(hits.into_iter());
        }
        let filter = if apps && cfg!(windows) {
            FileFilter::WindowsExecutables
        } else if apps && cfg!(target_os = "macos") {
            FileFilter::MacBundles
        } else {
            FileFilter::All
        };
        #[cfg(windows)]
        if roots.explicit.is_none() {
            return Self::Windows(drill_core::WindowsSearch::start(query, cancel, filter));
        }
        let roots = roots.explicit.map_or_else(
            || drill_core::default_roots_with_cancel(&cancel),
            |root| vec![root],
        );
        Self::Walk(Search::start_filtered(query, roots, cancel, filter))
    }

    fn next(&mut self) -> Result<Hit, TryRecvError> {
        match self {
            Self::Walk(search) => search.try_recv_hit().map(Into::into),
            #[cfg(windows)]
            Self::Windows(search) => search.try_recv_hit().map(Into::into),
            #[cfg(target_os = "linux")]
            Self::Apps(hits) => hits.next().ok_or(TryRecvError::Disconnected),
        }
    }
}

enum Delivery {
    Starting(mpsc::Receiver<Result<Option<Results>, String>>),
    Ready(Results),
}

pub(super) struct Session {
    cancel: Arc<AtomicBool>,
    delivery: Delivery,
}

pub(super) enum Poll {
    Hit(Hit),
    Waiting,
    Finished,
    Invalid(String),
}

impl Session {
    pub fn start(roots: Roots, text: String, apps: bool) -> Self {
        let cancel = Arc::new(AtomicBool::new(false));
        let worker_cancel = Arc::clone(&cancel);
        let (tx, rx) = mpsc::channel();
        // Root discovery, filesystem metadata and GIO enumeration may block.
        std::thread::spawn(move || {
            let query = SearchQuery::parse(&text);
            let results = if let Some(message) = query.error() {
                Err(message.to_owned())
            } else if query.is_empty() && !(apps && text.trim().is_empty()) {
                Ok(None)
            } else {
                Ok(Some(Results::start(roots, query, apps, worker_cancel)))
            };
            let _ = tx.send(results);
        });
        Self {
            cancel,
            delivery: Delivery::Starting(rx),
        }
    }

    pub fn next(&mut self) -> Poll {
        if let Delivery::Starting(rx) = &self.delivery {
            match rx.try_recv() {
                Ok(Ok(Some(results))) => self.delivery = Delivery::Ready(results),
                Ok(Ok(None)) => return Poll::Finished,
                Ok(Err(message)) => return Poll::Invalid(message),
                Err(TryRecvError::Empty) => return Poll::Waiting,
                Err(TryRecvError::Disconnected) => {
                    return Poll::Invalid("Could not start the search.".into())
                }
            }
        }
        let Delivery::Ready(results) = &mut self.delivery else {
            unreachable!()
        };
        match results.next() {
            Ok(hit) => Poll::Hit(hit),
            Err(TryRecvError::Empty) => Poll::Waiting,
            Err(TryRecvError::Disconnected) => Poll::Finished,
        }
    }

    pub fn set_paused(&mut self, paused: bool) {
        match &mut self.delivery {
            Delivery::Ready(Results::Walk(s)) => s.set_paused(paused),
            #[cfg(windows)]
            Delivery::Ready(Results::Windows(s)) => s.set_paused(paused),
            // Finite catalogs are pulled by the UI. Pausing needs no signal.
            #[cfg(target_os = "linux")]
            Delivery::Ready(Results::Apps(_)) => {}
            Delivery::Starting(_) => {}
        }
    }
}

impl Drop for Session {
    fn drop(&mut self) {
        self.cancel.store(true, Ordering::Relaxed);
        // Dropping a started Search also wakes paused and backpressured workers.
    }
}
