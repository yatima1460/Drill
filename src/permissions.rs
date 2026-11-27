use drill_macos::permissions::pick_folder;
use eframe::egui;
use std::path::{Path, PathBuf};
use std::sync::mpsc;

enum Completion {
    Folder(PathBuf, String),
    Settings(Result<(), String>),
}

pub struct Permissions {
    pub open: bool,
    roots: Vec<PathBuf>,
    checks: Vec<(PathBuf, String)>,
    receiver: mpsc::Receiver<Completion>,
    sender: mpsc::Sender<Completion>,
    pending: std::collections::HashSet<PathBuf>,
    settings_pending: bool,
    error: Option<String>,
}
impl Default for Permissions {
    fn default() -> Self {
        let (sender, receiver) = mpsc::channel();
        Self {
            open: false,
            roots: Vec::new(),
            checks: Vec::new(),
            receiver,
            sender,
            pending: Default::default(),
            settings_pending: false,
            error: None,
        }
    }
}
fn list_status(path: &Path) -> String {
    match std::fs::read_dir(path).and_then(|mut entries| entries.next().transpose().map(|_| ())) {
        Ok(_) => "Can list this folder".into(),
        Err(e) if e.kind() == std::io::ErrorKind::PermissionDenied => "Access denied".into(),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => "Unavailable".into(),
        Err(e) => format!("Unable to check: {e}"),
    }
}
fn settings_url(version: &str, pane: &str) -> String {
    let major = version
        .trim()
        .split('.')
        .next()
        .and_then(|n| n.parse::<u32>().ok())
        .unwrap_or(13);
    let domain = if major >= 13 {
        "com.apple.settings.PrivacySecurity.extension"
    } else {
        "com.apple.preference.security"
    };
    format!("x-apple.systempreferences:{domain}?{pane}")
}
fn open_settings(pane: &str) -> Result<(), String> {
    let version = std::process::Command::new("/usr/bin/sw_vers")
        .arg("-productVersion")
        .output()
        .map_err(|e| e.to_string())?;
    if !version.status.success() {
        return Err("Could not determine the macOS version".into());
    }
    let url = settings_url(&String::from_utf8_lossy(&version.stdout), pane);
    let status = std::process::Command::new("/usr/bin/open")
        .arg(url)
        .status()
        .map_err(|e| e.to_string())?;
    if status.success() {
        Ok(())
    } else {
        Err(format!("System Settings did not open ({status})"))
    }
}
impl Permissions {
    pub fn roots(&self) -> Vec<PathBuf> {
        self.roots.clone()
    }
    fn choose(&mut self, starting_folder: Option<PathBuf>, ctx: &egui::Context) -> bool {
        if let Some(path) = pick_folder(starting_folder.as_deref()) {
            if !self.roots.contains(&path) {
                self.roots.push(path.clone());
            }
            if self.pending.contains(&path) {
                return true;
            }
            if self.pending.len() >= 4 {
                self.checks.retain(|(p, _)| p != &path);
                self.checks
                    .push((path, "Not checked: wait for other checks to finish".into()));
                return true;
            }
            self.pending.insert(path.clone());
            self.checks.retain(|(p, _)| p != &path);
            self.checks.push((path.clone(), "Checking…".into()));
            let tx = self.sender.clone();
            let ctx = ctx.clone();
            std::thread::spawn(move || {
                let status = list_status(&path);
                let _ = tx.send(Completion::Folder(path, status));
                ctx.request_repaint();
            });
            return true;
        }
        false
    }
    pub fn show(&mut self, ctx: &egui::Context) -> bool {
        while let Ok(completion) = self.receiver.try_recv() {
            match completion {
                Completion::Folder(path, status) => {
                    self.pending.remove(&path);
                    if let Some((_, value)) = self.checks.iter_mut().find(|(p, _)| *p == path) {
                        *value = format!("Last checked: {status}");
                    }
                }
                Completion::Settings(result) => {
                    self.settings_pending = false;
                    self.error = result.err();
                }
            }
        }
        if !self.open {
            return false;
        }
        let mut open = self.open;
        let mut chosen = None;
        let mut settings = None;
        egui::Window::new("Permissions").open(&mut open).default_width(480.0).vscroll(true).show(ctx, |ui| {
            ui.label("Choose a folder to let macOS request access for Drill and include it in searches during this session.");
            ui.label("macOS controls access. A successful check only confirms that the selected folder can be listed.");
            ui.add_space(8.0);
            let home = std::env::var_os("HOME").map(PathBuf::from);
            for (name, relative) in [("Desktop", "Desktop"), ("Documents", "Documents"), ("Downloads", "Downloads"), ("iCloud Drive", "Library/Mobile Documents/com~apple~CloudDocs")] {
                if ui.button(format!("Choose {name}…")).clicked() { chosen = Some(home.as_ref().map(|p| p.join(relative))); }
            }
            if ui.button("Choose another folder…").clicked() { chosen = Some(None); }
            ui.separator();
            if ui.add_enabled(!self.settings_pending, egui::Button::new("Open Files and Folders Settings…")).clicked() { settings = Some("Privacy_FilesAndFolders"); }
            if ui.add_enabled(!self.settings_pending, egui::Button::new("Open Full Disk Access Settings…")).clicked() { settings = Some("Privacy_AllFiles"); }
            ui.label("To grant Full Disk Access, add or enable Drill in System Settings → Privacy & Security → Full Disk Access.");
            if let Some(error) = &self.error { ui.label(format!("Could not open Settings: {error}")); }
            for (path, status) in &self.checks { ui.label(format!("{}: {status}", path.display())); }
        });
        self.open = open;
        if let Some(pane) = settings {
            self.settings_pending = true;
            self.error = None;
            let tx = self.sender.clone();
            let ctx = ctx.clone();
            std::thread::spawn(move || {
                let result = open_settings(pane);
                let _ = tx.send(Completion::Settings(result));
                ctx.request_repaint();
            });
        }
        if let Some(path) = chosen {
            return self.choose(path, ctx);
        }
        false
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn settings_urls_cover_supported_macos_versions() {
        assert!(settings_url("15.1", "Privacy_AllFiles")
            .contains("com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles"));
        assert!(settings_url("12.7", "Privacy_AllFiles")
            .contains("com.apple.preference.security?Privacy_AllFiles"));
    }
    #[test]
    fn listing_status_reports_readable_and_missing_folders() {
        assert_eq!(list_status(&std::env::temp_dir()), "Can list this folder");
        assert_eq!(
            list_status(&std::env::temp_dir().join("drill-missing-permission-check-33d9f")),
            "Unavailable"
        );
    }
}
