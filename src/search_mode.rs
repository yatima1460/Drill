#[cfg(any(not(windows), test, feature = "ui-test-driver"))]
use drill_core::Search;
use drill_core::{Entry, FileFilter, MatchKind};
use std::sync::mpsc::TryRecvError;

#[derive(Clone, Copy, Default, PartialEq, Eq)]
pub(super) enum Mode {
    #[default]
    Files,
    Apps,
}

impl Mode {
    pub(super) fn label(self) -> &'static str {
        match self {
            Self::Files => "Files",
            Self::Apps => "Apps",
        }
    }

    pub(super) fn file_filter(self) -> FileFilter {
        match self {
            Self::Apps if cfg!(target_os = "macos") => FileFilter::MacBundles,
            Self::Apps if cfg!(windows) => FileFilter::WindowsExecutables,
            _ => FileFilter::All,
        }
    }
}

pub(super) enum Results {
    #[cfg(any(not(windows), test, feature = "ui-test-driver"))]
    Walk(Search),
    #[cfg(windows)]
    Windows(drill_core::WindowsSearch),
    #[cfg(target_os = "linux")]
    Apps(std::vec::IntoIter<(MatchKind, Entry)>),
}

impl Results {
    pub(super) fn try_recv_hit(&mut self) -> Result<(MatchKind, Entry), TryRecvError> {
        match self {
            #[cfg(any(not(windows), test, feature = "ui-test-driver"))]
            Self::Walk(search) => search.try_recv_hit(),
            #[cfg(windows)]
            Self::Windows(search) => search.try_recv_hit(),
            #[cfg(target_os = "linux")]
            Self::Apps(hits) => hits.next().ok_or(TryRecvError::Disconnected),
        }
    }

    pub(super) fn set_paused(&mut self, paused: bool) {
        match self {
            #[cfg(any(not(windows), test, feature = "ui-test-driver"))]
            Self::Walk(search) => search.set_paused(paused),
            #[cfg(windows)]
            Self::Windows(search) => search.set_paused(paused),
            #[cfg(target_os = "linux")]
            Self::Apps(_) => {} // The UI controls iteration over the finite installed app list.
        }
    }

    pub(super) fn directories_pending(&self) -> Option<usize> {
        match self {
            #[cfg(any(not(windows), test, feature = "ui-test-driver"))]
            Self::Walk(search) => Some(search.pending()),
            #[cfg(windows)]
            Self::Windows(search) => search.pending(),
            #[cfg(target_os = "linux")]
            Self::Apps(_) => None,
        }
    }
}
