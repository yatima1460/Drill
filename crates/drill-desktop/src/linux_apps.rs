use crate::search::Hit;
use drill_core::{Entry, MatchKind, SearchQuery};
use drill_gtk::linux_app_catalog::{self, DesktopApp};
use std::ffi::CString;
use std::sync::atomic::{AtomicBool, Ordering};

fn classify(app: &DesktopApp, query: &SearchQuery) -> Option<MatchKind> {
    let filename = app.path.file_name()?.to_string_lossy();
    let mut partial = false;
    for value in [app.display_name.as_str(), &app.id, &filename] {
        match query.classify(value) {
            Some(MatchKind::Exact) => return Some(MatchKind::Exact),
            Some(MatchKind::Partial) => partial = true,
            None => {}
        }
    }
    (partial || (!app.keywords.is_empty() && query.classify(&app.keywords).is_some()))
        .then_some(MatchKind::Partial)
}

// GIO chooses the visible desktop file for each registered app ID, including
// user overrides and nested application directories. A file walk cannot do this.
pub(super) struct Catalog(Vec<DesktopApp>);

impl Catalog {
    pub(super) fn load() -> Self {
        let mut apps = linux_app_catalog::load();
        apps.sort_by_cached_key(|app| (app.display_name.to_lowercase(), app.id.clone()));
        Self(apps)
    }

    pub(super) fn search(&self, query: &SearchQuery, cancel: &AtomicBool) -> Vec<Hit> {
        self.0
            .iter()
            .take_while(|_| !cancel.load(Ordering::Relaxed))
            .filter_map(|app| {
                let rank = classify(app, query)?;
                Some(Hit {
                    rank,
                    entry: Entry {
                        path: app.path.clone(),
                        name: app.display_name.clone(),
                        size: None,
                        modified: None,
                        is_dir: false,
                    },
                    desktop_id: Some(CString::new(app.id.as_str()).ok()?),
                })
            })
            .collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use drill_gtk::linux_app_catalog::LaunchError;
    use std::{env, fs, path::Path, process::Command};

    #[test]
    fn registered_apps_follow_xdg() {
        const FIXTURE: &str = "DRILL_TEST_XDG_CATALOG";
        if env::var_os(FIXTURE).is_some() {
            check_catalog();
            return;
        }

        // GIO caches XDG paths and the current desktop. Give it a fresh process.
        let root = crate::test_directory::private_temp_dir();
        let user = root.path().join("user/applications");
        let system = root.path().join("system/applications");
        fs::create_dir_all(user.join("suite")).unwrap();
        fs::create_dir_all(&system).unwrap();
        let desktop = |name, extra| {
            format!("[Desktop Entry]\nType=Application\nName={name}\nExec=/bin/true\n{extra}\n")
        };
        for (path, name, extra) in [
            (system.join("override.desktop"), "Replaced", ""),
            (user.join("override.desktop"), "Alpha", ""),
            (system.join("masked.desktop"), "Masked", ""),
            (user.join("masked.desktop"), "Hidden", "Hidden=true"),
            (user.join("quiet.desktop"), "Background", "NoDisplay=true"),
            (user.join("other.desktop"), "Other", "OnlyShowIn=Other;"),
            (
                user.join("suite/editor.desktop"),
                "Editor",
                "Name[sl]=Urejevalnik\nKeywords=writing;text;\nIcon=accessories-text-editor",
            ),
        ] {
            fs::write(path, desktop(name, extra)).unwrap();
        }
        let test = concat!(module_path!(), "::registered_apps_follow_xdg");
        let output = Command::new(env::current_exe().unwrap())
            .args(["--exact", test.split_once("::").unwrap().1, "--nocapture"])
            .env(FIXTURE, "1")
            .env("XDG_DATA_HOME", user.parent().unwrap())
            .env("XDG_DATA_DIRS", system.parent().unwrap())
            .env("XDG_CURRENT_DESKTOP", "DrillTest")
            .env("LANGUAGE", "sl")
            .env("LC_ALL", "C.UTF-8")
            .output()
            .unwrap();
        assert!(
            output.status.success() && String::from_utf8_lossy(&output.stdout).contains("1 passed"),
            "{output:?}"
        );
    }

    fn check_catalog() {
        let cancel = AtomicBool::new(false);
        let catalog = Catalog::load();
        let search = |text| catalog.search(&SearchQuery::parse(text), &cancel);
        let entries = search("");
        let names: Vec<_> = entries.iter().map(|hit| hit.entry.name.as_str()).collect();
        assert_eq!(names, ["Alpha", "Urejevalnik"]);
        let path = &entries[1].entry.path;
        let desktop_id = entries[1].desktop_id.as_deref().unwrap().to_str().unwrap();
        assert_eq!(desktop_id, "suite-editor.desktop");
        for (query, kind) in [
            ("urejevalnik", MatchKind::Exact),
            ("suite-editor.desktop", MatchKind::Exact),
            ("editor.desktop", MatchKind::Exact),
            ("writing", MatchKind::Partial),
            ("*editor.desktop", MatchKind::Partial),
            ("regex:^urej", MatchKind::Partial),
            ("glob:*writing*", MatchKind::Partial),
        ] {
            let hits = search(query);
            assert_eq!(hits.len(), 1, "{query}");
            assert_eq!((hits[0].rank, &hits[0].entry.path), (kind, path), "{query}");
        }
        assert!(search("fuzzy:").is_empty());
        assert!(search("regex:^$").is_empty());
        let app = catalog.0.iter().find(|app| &app.path == path).unwrap();
        assert!(app
            .icon_names
            .iter()
            .any(|n| n == "accessories-text-editor"));
        assert!(linux_app_catalog::launch(desktop_id, path).is_ok()); // Runs /bin/true.
        assert!(matches!(
            linux_app_catalog::launch("suite-editor.desktop", Path::new("/tmp/replaced.desktop")),
            Err(LaunchError::Unavailable)
        ));
        let hidden = std::path::PathBuf::from(env::var_os("XDG_DATA_HOME").unwrap())
            .join("applications/quiet.desktop");
        assert!(matches!(
            linux_app_catalog::launch("quiet.desktop", &hidden),
            Err(LaunchError::Unavailable)
        ));
        cancel.store(true, Ordering::Relaxed);
        assert!(search("").is_empty());
    }
}
