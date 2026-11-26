use drill_core::{Entry, MatchKind, SearchQuery};
use gio_unix::DesktopAppInfo;
use gtk::gio::{self, prelude::*};
use std::path::Path;
use std::sync::atomic::{AtomicBool, Ordering};

struct Application {
    entry: Entry,
    id: String,
    keywords: String,
    icon_names: Vec<String>,
}

impl Application {
    fn from_registered(app: gio::AppInfo) -> Option<Self> {
        let app = app.downcast::<DesktopAppInfo>().ok()?;
        if !app.should_show() {
            return None;
        }
        let icon_names = app
            .icon()
            .and_then(|icon| icon.downcast::<gio::ThemedIcon>().ok())
            .map(|icon| icon.names().into_iter().map(String::from).collect())
            .unwrap_or_default();
        Some(Self {
            entry: Entry {
                path: app.filename()?,
                name: app.display_name().to_string(),
                size: None,
                modified: None,
                is_dir: false,
            },
            id: app.id()?.to_string(),
            keywords: app.keywords().join(" "),
            icon_names,
        })
    }

    fn classify(&self, query: &SearchQuery) -> Option<MatchKind> {
        let filename = self.entry.path.file_name()?.to_string_lossy();
        let mut partial = false;
        for value in [self.entry.name.as_str(), &self.id, &filename] {
            match query.classify(value) {
                Some(MatchKind::Exact) => return Some(MatchKind::Exact),
                Some(MatchKind::Partial) => partial = true,
                None => {}
            }
        }
        (partial || query.classify(&self.keywords).is_some()).then_some(MatchKind::Partial)
    }
}

// Retain owned data so searches can run on a worker without sharing GIO objects.
pub(super) struct Catalog {
    apps: Vec<Application>,
}

impl Catalog {
    pub(super) fn load() -> Self {
        let mut apps: Vec<_> = gio::AppInfo::all()
            .into_iter()
            .filter_map(Application::from_registered)
            .collect();
        apps.sort_by_cached_key(|app| (app.entry.name.to_lowercase(), app.id.clone()));
        Self { apps }
    }

    pub(super) fn search(
        &self,
        query: &SearchQuery,
        cancel: &AtomicBool,
    ) -> Vec<(MatchKind, Entry)> {
        self.apps
            .iter()
            .take_while(|_| !cancel.load(Ordering::Relaxed))
            .filter_map(|app| Some((app.classify(query)?, app.entry.clone())))
            .collect()
    }

    fn find(&self, path: &Path) -> Option<&Application> {
        self.apps.iter().find(|app| app.entry.path == path)
    }

    pub(super) fn icon_names(&self, path: &Path) -> &[String] {
        self.find(path).map_or(&[], |app| app.icon_names.as_slice())
    }

    pub(super) fn launch(&self, path: &Path) -> Result<(), String> {
        let registered = self.find(path).ok_or("Unknown application")?;
        let app = DesktopAppInfo::new(&registered.id)
            .filter(|app| app.should_show() && app.filename().as_deref() == Some(path))
            .ok_or_else(|| format!("{} is no longer available", registered.entry.name))?;
        app.launch(&[], None::<&gio::AppLaunchContext>)
            .map_err(|err| err.to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::{env, fs, process::Command};

    #[test]
    fn registered_apps_follow_xdg() {
        const FIXTURE: &str = "DRILL_TEST_XDG_CATALOG";
        if env::var_os(FIXTURE).is_some() {
            check_catalog();
            return;
        }

        // GIO caches XDG paths and the current desktop. Give it a fresh process.
        let root = tempfile::tempdir().unwrap();
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
        let catalog = Catalog::load();
        let cancel = AtomicBool::new(false);
        let search = |text| catalog.search(&SearchQuery::parse(text), &cancel);
        let entries = search("");
        let names: Vec<_> = entries.iter().map(|(_, app)| app.name.as_str()).collect();
        assert_eq!(names, ["Alpha", "Urejevalnik"]);
        let path = &entries[1].1.path;
        for (query, kind) in [
            ("urejevalnik", MatchKind::Exact),
            ("suite-editor.desktop", MatchKind::Exact),
            ("editor.desktop", MatchKind::Exact),
            ("writing", MatchKind::Partial),
        ] {
            let hits = search(query);
            assert_eq!(hits.len(), 1, "{query}");
            assert_eq!((hits[0].0, &hits[0].1.path), (kind, path), "{query}");
        }
        assert!(search("fuzzy:").is_empty());
        assert!(catalog
            .icon_names(path)
            .iter()
            .any(|n| n == "accessories-text-editor"));
        assert!(catalog
            .launch(Path::new("/tmp/unregistered.desktop"))
            .is_err());
        catalog.launch(path).unwrap(); // The fixture launches /bin/true.
        cancel.store(true, Ordering::Relaxed);
        assert!(search("").is_empty());
    }
}
