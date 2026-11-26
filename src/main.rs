#![cfg_attr(target_os = "windows", windows_subsystem = "windows")]
#![deny(unsafe_code)]
use chrono::{DateTime, Local};
use drill_core::{default_roots_with_cancel, Entry, MatchKind, Search, SearchQuery};
use eframe::egui::{self, Key};
use std::path::Path;
use std::time::{Duration, Instant};
mod exe_icon;
mod search_mode;
use search_mode::{Mode, Results};
#[cfg(target_os = "linux")]
mod linux_apps;
#[cfg(any(target_os = "macos", target_os = "windows"))]
mod native_menu;
#[cfg(target_os = "macos")]
mod permissions;

const LIMIT: usize = 10_000;
fn embedded_icons_setting(storage: Option<&dyn eframe::Storage>) -> bool {
    storage
        .and_then(|storage| storage.get_string("embedded_exe_icons"))
        .and_then(|value| value.parse().ok())
        .unwrap_or(true)
}
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum SortColumn {
    Name,
    Path,
    Size,
    Date,
}

fn compare_entries(a: &Entry, b: &Entry, column: SortColumn) -> std::cmp::Ordering {
    let ordering = match column {
        SortColumn::Name => a.name.to_lowercase().cmp(&b.name.to_lowercase()),
        SortColumn::Path => a.path.parent().cmp(&b.path.parent()),
        SortColumn::Size => a.size.cmp(&b.size),
        SortColumn::Date => a.modified.cmp(&b.modified),
    };
    ordering.then_with(|| a.path.cmp(&b.path))
}

// Dividers transfer width only between adjacent columns, preserving their sum.
fn resize_columns(widths: &mut [f32; 4], divider: usize, delta: f32, total: f32) {
    if total <= 0.0 {
        return;
    }
    let minima = [80.0, 80.0, 60.0, 90.0];
    let scale = (total / 310.0_f32).min(1.0);
    let pair = widths[divider] + widths[divider + 1];
    let mut left_min = minima[divider] * scale / total;
    let mut right_min = minima[divider + 1] * scale / total;
    if left_min + right_min > pair {
        // Leave room to move the divider when the pair is already too narrow
        // to satisfy both preferred minima.
        let factor = 0.8 * pair / (left_min + right_min);
        left_min *= factor;
        right_min *= factor;
    }
    // Existing proportions can be below the preferred minima after a window
    // resize. Never move the divider merely to enforce a new minimum.
    let current = widths[divider];
    let lower = left_min.min(current);
    let upper = (pair - right_min).max(current);
    let left = (current + delta / total).clamp(lower, upper);
    widths[divider] = left;
    widths[divider + 1] = pair - left;
}
struct App {
    query: String,
    changed: Option<Instant>,
    mode: Mode,
    selector_open: bool,
    #[cfg(target_os = "linux")]
    catalog: Option<std::sync::Arc<linux_apps::Catalog>>,
    #[cfg(target_os = "linux")]
    catalog_loading: Option<std::sync::mpsc::Receiver<linux_apps::Catalog>>,
    search: Option<Results>,
    starting: Option<std::sync::mpsc::Receiver<Results>>,
    starting_cancel: Option<std::sync::Arc<std::sync::atomic::AtomicBool>>,
    completed: bool,
    results: Vec<Entry>,
    selected: Option<usize>,
    last_clicked_file: Option<std::path::PathBuf>,
    exact_count: usize,
    result_limit: usize,
    next_hit: Option<(MatchKind, Entry)>,
    stopped: bool,
    focus_search: bool,
    scroll_offset: f32,
    icons: std::collections::HashMap<std::path::PathBuf, Option<egui::TextureHandle>>,
    icon_worker: Option<exe_icon::Worker>,
    pending_icons: std::collections::HashSet<std::path::PathBuf>,
    exe_type_icon: Option<Option<egui::TextureHandle>>,
    icon_generation: u64,
    embedded_exe_icons: bool,
    interface_open: bool,
    sort: Option<(SortColumn, bool)>,
    column_widths: [f32; 4],
    column_drag: Option<(usize, f32, [f32; 4])>,
    action_error: Option<String>,
    action_result: Option<std::sync::mpsc::Receiver<Result<(), String>>>,
    action_error_sender: std::sync::mpsc::Sender<String>,
    action_errors: std::sync::mpsc::Receiver<String>,
    #[cfg(any(target_os = "macos", target_os = "windows"))]
    native_menu: Option<native_menu::NativeMenu>,
    #[cfg(target_os = "macos")]
    permissions: permissions::Permissions,
}
impl Default for App {
    fn default() -> Self {
        let (action_error_sender, action_errors) = std::sync::mpsc::channel();
        Self {
            query: String::new(),
            changed: None,
            mode: Mode::Files,
            selector_open: false,
            #[cfg(target_os = "linux")]
            catalog: None,
            #[cfg(target_os = "linux")]
            catalog_loading: None,
            search: None,
            starting: None,
            starting_cancel: None,
            completed: false,
            results: Vec::new(),
            selected: None,
            last_clicked_file: None,
            exact_count: 0,
            result_limit: LIMIT,
            next_hit: None,
            stopped: false,
            focus_search: true,
            scroll_offset: 0.0,
            icons: std::collections::HashMap::new(),
            icon_worker: None,
            pending_icons: Default::default(),
            exe_type_icon: None,
            icon_generation: 0,
            embedded_exe_icons: true,
            interface_open: false,
            sort: None,
            column_widths: [0.35, 0.35, 0.1, 0.2],
            column_drag: None,
            action_error: None,
            action_result: None,
            action_error_sender,
            action_errors,
            #[cfg(any(target_os = "macos", target_os = "windows"))]
            native_menu: None,
            #[cfg(target_os = "macos")]
            permissions: permissions::Permissions::default(),
        }
    }
}
fn size(entry: &Entry) -> String {
    let Some(bytes) = entry.size else {
        return "?".into();
    };
    if entry.is_dir && bytes == 0 {
        return String::new();
    }
    if bytes == 0 {
        return "Empty".into();
    }
    if bytes < 1024 {
        return "1 KB".into();
    }
    let mut n = bytes as f64;
    for unit in ["B", "KB", "MB", "GB", "TB", "PB"] {
        if n < 1024.0 {
            return format!("{n:.0} {unit}");
        }
        n /= 1024.0;
    }
    format!("{n:.1} EB")
}
fn date(entry: &Entry) -> String {
    entry
        .modified
        .map(|t| {
            DateTime::<Local>::from(t)
                .format("%Y/%m/%d %H:%M:%S")
                .to_string()
        })
        .unwrap_or_else(|| "?".into())
}
// Qt's result list used 32 logical pixels. Keep native art sharp on a 2× display.
const RESULT_ICON_SIZE: f32 = 32.0;
const NATIVE_ICON_PIXELS: u16 = 64;
const RESULT_ROW_PITCH: f32 = 36.0;

fn platform_icon_texture(
    ctx: &egui::Context,
    icon: file_icon_provider::Icon,
    name: &str,
) -> Option<egui::TextureHandle> {
    let pixels = (icon.width as usize).checked_mul(icon.height as usize)?;
    let rgba = if icon.pixels.len() == pixels.checked_mul(4)? {
        icon.pixels
    } else if icon.pixels.len() == pixels.checked_mul(3)? {
        icon.pixels
            .as_chunks::<3>()
            .0
            .iter()
            .flat_map(|rgb| [rgb[0], rgb[1], rgb[2], 255])
            .collect()
    } else {
        return None;
    };
    let dimensions = [icon.width as usize, icon.height as usize];
    #[cfg(any(target_os = "macos", target_os = "windows"))]
    let image = egui::ColorImage::from_rgba_premultiplied(dimensions, &rgba);
    #[cfg(not(any(target_os = "macos", target_os = "windows")))]
    let image = egui::ColorImage::from_rgba_unmultiplied(dimensions, &rgba);
    Some(ctx.load_texture(name, image, egui::TextureOptions::LINEAR))
}
#[cfg(not(target_os = "linux"))]
fn executable_type_icon(ctx: &egui::Context) -> Option<egui::TextureHandle> {
    // Ask the OS about a private, empty sample; never pass it the untrusted executable.
    let sample = tempfile::Builder::new().suffix(".exe").tempfile().ok()?;
    let icon = file_icon_provider::get_file_icon(sample.path(), NATIVE_ICON_PIXELS).ok()?;
    platform_icon_texture(ctx, icon, "exe-type-icon")
}
#[cfg(target_os = "linux")]
fn executable_type_icon(ctx: &egui::Context) -> Option<egui::TextureHandle> {
    use gtk::prelude::*;
    if !gtk::is_initialized() {
        gtk::init().ok()?;
    }
    let (content_type, _) = gtk::gio::content_type_guess(Some(Path::new("application.exe")), None);
    let icon = gtk::gio::content_type_get_icon(&content_type);
    let themed = icon.dynamic_cast_ref::<gtk::gio::ThemedIcon>()?;
    themed_icon_texture(
        ctx,
        themed.names().iter().map(|name| name.as_str()),
        "exe-type-icon",
    )
}

#[cfg(target_os = "linux")]
fn themed_icon_texture<'a>(
    ctx: &egui::Context,
    names: impl Iterator<Item = &'a str>,
    key: &str,
) -> Option<egui::TextureHandle> {
    use gtk::prelude::*;
    if !gtk::is_initialized() {
        gtk::init().ok()?;
    }
    let theme = gtk::IconTheme::default()?;
    for name in names {
        if let Some(pixbuf) = theme
            .load_icon(
                name,
                i32::from(NATIVE_ICON_PIXELS),
                gtk::IconLookupFlags::empty(),
            )
            .ok()
            .flatten()
        {
            let width = u32::try_from(pixbuf.width()).ok()?;
            let height = u32::try_from(pixbuf.height()).ok()?;
            let icon = file_icon_provider::Icon {
                width,
                height,
                pixels: pixbuf.read_pixel_bytes().to_vec(),
            };
            if let Some(texture) = platform_icon_texture(ctx, icon, key) {
                return Some(texture);
            }
        }
    }
    None
}
#[cfg(not(target_os = "linux"))]
fn open(path: &Path, reveal: bool) {
    #[cfg(target_os = "macos")]
    let mut command = {
        let mut c = std::process::Command::new("open");
        if reveal {
            c.arg("-R");
        }
        c
    };
    #[cfg(target_os = "windows")]
    let mut command = {
        let mut c = std::process::Command::new("explorer");
        if reveal {
            c.arg("/select,");
        }
        c
    };
    #[cfg(not(any(target_os = "macos", target_os = "windows")))]
    let mut command = std::process::Command::new("xdg-open");
    #[cfg(not(any(target_os = "macos", target_os = "windows")))]
    let path = if reveal {
        path.parent().unwrap_or(path)
    } else {
        path
    };
    if let Err(error) = command.arg(path).spawn() {
        eprintln!("Cannot open {}: {error}", path.display());
    }
}

#[cfg(target_os = "linux")]
fn open_linux_path(
    path: &Path,
    reveal: bool,
    errors: std::sync::mpsc::Sender<String>,
    ctx: egui::Context,
) {
    let target = if reveal {
        path.parent().unwrap_or(path)
    } else {
        path
    }
    .to_owned();
    std::thread::spawn(move || {
        // Some desktop handlers keep xdg-open alive until their window closes.
        let reason = match std::process::Command::new("xdg-open").arg(&target).status() {
            Ok(status) if status.success() => return,
            Ok(status) => format!("xdg-open exited with {status}"),
            Err(error) => error.to_string(),
        };
        let _ = errors.send(format!("Cannot open {}: {reason}", target.display()));
        ctx.request_repaint();
    });
}

fn terminal_directory(entry: &Entry) -> &Path {
    if entry.is_dir || entry.path.is_dir() {
        &entry.path
    } else {
        entry.path.parent().unwrap_or(&entry.path)
    }
}

fn open_terminal(directory: &Path) -> Result<std::process::Child, String> {
    if !directory.is_dir() {
        return Err(format!("Folder is unavailable: {}", directory.display()));
    }
    #[cfg(target_os = "macos")]
    let candidates: &[(&str, &[&str])] = &[("/usr/bin/open", &["-b", "com.apple.Terminal"])];
    #[cfg(target_os = "windows")]
    let candidates: &[(&str, &[&str])] =
        &[("wt.exe", &["new-tab", "-d", "."]), ("powershell.exe", &[])];
    #[cfg(not(any(target_os = "macos", target_os = "windows")))]
    let candidates: &[(&str, &[&str])] = &[
        ("xdg-terminal-exec", &[]),
        ("x-terminal-emulator", &[]),
        ("gnome-terminal", &[]),
        ("konsole", &[]),
        ("xfce4-terminal", &[]),
        ("xterm", &[]),
    ];
    for (program, args) in candidates {
        let mut command = std::process::Command::new(program);
        command.args(*args).current_dir(directory);
        #[cfg(target_os = "macos")]
        command.arg(directory);
        #[cfg(target_os = "windows")]
        {
            use std::os::windows::process::CommandExt;
            command.creation_flags(0x0000_0010); // CREATE_NEW_CONSOLE
        }
        match command.spawn() {
            Ok(child) => return Ok(child),
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => continue,
            Err(error) => return Err(format!("Cannot start terminal: {error}")),
        }
    }
    Err("No supported terminal application was found".into())
}

#[cfg(target_os = "macos")]
fn open_with(path: &Path) -> Result<(), String> {
    let script = "try\nset chosenApp to choose application with prompt \"Open with:\" as alias\nreturn POSIX path of chosenApp\non error number -128\nreturn \"\"\nend try";
    let output = std::process::Command::new("/usr/bin/osascript")
        .args(["-e", script])
        .output()
        .map_err(|e| e.to_string())?;
    if !output.status.success() {
        return Err(String::from_utf8_lossy(&output.stderr).trim().to_owned());
    }
    let app = String::from_utf8_lossy(&output.stdout);
    let app = app.trim();
    if app.is_empty() {
        return Ok(());
    }
    let status = std::process::Command::new("/usr/bin/open")
        .arg("-a")
        .arg(app)
        .arg(path)
        .status()
        .map_err(|e| e.to_string())?;
    if status.success() {
        Ok(())
    } else {
        Err(format!(
            "Could not open {} with the selected application",
            path.display()
        ))
    }
}

#[cfg(target_os = "linux")]
#[allow(unsafe_code)]
fn open_with(path: &Path) -> Result<(), String> {
    use gtk::prelude::*;
    gtk::init().map_err(|e| e.to_string())?;
    let file = gtk::gio::File::for_path(path);
    let dialog = gtk::AppChooserDialog::new(None::<&gtk::Window>, gtk::DialogFlags::MODAL, &file);
    let response = dialog.run();
    let result = if response == gtk::ResponseType::Ok || response == gtk::ResponseType::Accept {
        match dialog.app_info() {
            Some(app) => app
                .launch(&[file], None::<&gtk::gio::AppLaunchContext>)
                .map_err(|e| e.to_string()),
            None => Err("No application was selected".into()),
        }
    } else {
        Ok(())
    };
    dialog.hide();
    // SAFETY: the dialog has returned from its modal loop and is not queried or reused after destruction.
    unsafe { dialog.destroy() };
    result
}

#[cfg(windows)]
#[allow(unsafe_code)]
fn launch_windows_app(path: &Path) -> Result<(), String> {
    use std::os::windows::ffi::OsStrExt;
    use windows_sys::Win32::UI::{Shell::ShellExecuteW, WindowsAndMessaging::SW_SHOWNORMAL};
    let wide: Vec<_> = path.as_os_str().encode_wide().chain(Some(0)).collect();
    // SAFETY: the path and verb are terminated UTF-16 and live for the call.
    // Null optional parameters ask the shell to open the app with its normal policy.
    let result = unsafe {
        ShellExecuteW(
            std::ptr::null_mut(),
            windows_sys::core::w!("open"),
            wide.as_ptr(),
            std::ptr::null(),
            std::ptr::null(),
            SW_SHOWNORMAL,
        )
    } as isize;
    if result > 32 {
        Ok(())
    } else {
        Err(format!("Windows shell error {result}"))
    }
}

#[cfg(target_os = "windows")]
#[allow(unsafe_code)]
fn open_with(path: &Path) -> Result<(), String> {
    use std::os::windows::ffi::OsStrExt;
    use windows_sys::Win32::System::Com::{
        CoInitializeEx, CoUninitialize, COINIT_APARTMENTTHREADED,
    };
    use windows_sys::Win32::UI::Shell::{SHOpenWithDialog, OAIF_EXEC, OPENASINFO};
    let wide: Vec<u16> = path.as_os_str().encode_wide().chain(Some(0)).collect();
    let info = OPENASINFO {
        pcszFile: wide.as_ptr(),
        pcszClass: std::ptr::null(),
        oaifInFlags: OAIF_EXEC,
    };
    // SAFETY: this fresh thread initializes COM as a single-threaded apartment.
    let initialized = unsafe { CoInitializeEx(std::ptr::null(), COINIT_APARTMENTTHREADED as u32) };
    if initialized < 0 {
        return Err(format!(
            "Cannot initialize application chooser (0x{:08x})",
            initialized as u32
        ));
    }
    // SAFETY: the NUL-terminated filename and OPENASINFO remain alive throughout the call.
    let result = unsafe { SHOpenWithDialog(std::ptr::null_mut(), &info) };
    // SAFETY: CoInitializeEx succeeded on this thread and is balanced exactly once.
    unsafe { CoUninitialize() };
    if result >= 0 || result as u32 == 0x8007_04c7 {
        Ok(())
    } else {
        Err(format!("Open with failed (0x{:08x})", result as u32))
    }
}

#[cfg(not(any(target_os = "macos", target_os = "windows", target_os = "linux")))]
fn open_with(_path: &Path) -> Result<(), String> {
    Err("Open with is unavailable on this platform".into())
}

enum MenuIcon {
    Folder,
    Terminal,
}
fn icon_menu_button(ui: &mut egui::Ui, text: &str, icon: MenuIcon) -> bool {
    let width = ui.available_width().max(190.0);
    let (row, response) = ui.allocate_exact_size(
        egui::vec2(width, ui.spacing().interact_size.y),
        egui::Sense::click(),
    );
    response.widget_info(|| egui::WidgetInfo::labeled(egui::WidgetType::Button, true, text));
    let visuals = ui.style().interact(&response);
    let p = ui.painter();
    if response.hovered() || response.has_focus() {
        p.rect_filled(row, visuals.corner_radius, visuals.bg_fill);
    }
    let rect = egui::Rect::from_min_size(
        egui::pos2(row.left() + 4.0, row.center().y - 8.0),
        egui::vec2(16.0, 16.0),
    );
    let stroke = egui::Stroke::new(1.2_f32, visuals.text_color());
    let at = |x, y| rect.min + egui::vec2(x, y);
    match icon {
        MenuIcon::Terminal => {
            p.rect_stroke(rect.shrink(1.0), 2.0, stroke, egui::StrokeKind::Inside);
            p.line_segment([at(4.0, 5.0), at(7.0, 8.0)], stroke);
            p.line_segment([at(7.0, 8.0), at(4.0, 11.0)], stroke);
            p.line_segment([at(9.0, 11.0), at(12.0, 11.0)], stroke);
        }
        MenuIcon::Folder => {
            p.line(
                vec![
                    at(1.0, 13.0),
                    at(1.0, 3.0),
                    at(6.0, 3.0),
                    at(8.0, 5.0),
                    at(15.0, 5.0),
                    at(15.0, 13.0),
                    at(1.0, 13.0),
                ],
                stroke,
            );
        }
    }
    p.text(
        egui::pos2(row.left() + 26.0, row.center().y),
        egui::Align2::LEFT_CENTER,
        text,
        egui::TextStyle::Button.resolve(ui.style()),
        visuals.text_color(),
    );
    response.clicked()
}

#[cfg(any(test, not(any(target_os = "macos", target_os = "windows"))))]
fn in_window_search_menu(ctx: &egui::Context, app: &mut App) {
    egui::TopBottomPanel::top("menu_bar").show(ctx, |ui| {
        egui::menu::bar(ui, |ui| {
            ui.menu_button("Search", |ui| {
                if ui
                    .add_enabled(app.can_stop(), egui::Button::new("Stop"))
                    .clicked()
                {
                    app.stop_search();
                    ui.close_menu();
                }
            });
            ui.menu_button("Settings", |ui| {
                if ui.button("Interface…").clicked() {
                    app.interface_open = true;
                    ui.close_menu();
                }
            });
        });
    });
}
impl App {
    fn can_stop(&self) -> bool {
        self.changed.is_some()
            || self.starting.is_some()
            || (self.search.is_some() && !self.completed)
    }

    fn stop_search(&mut self) {
        if !self.can_stop() {
            return;
        }
        self.changed = None;
        if let Some(cancel) = self.starting_cancel.take() {
            cancel.store(true, std::sync::atomic::Ordering::Relaxed);
        }
        self.starting = None;
        self.search = None;
        self.completed = false;
        self.next_hit = None;
        self.stopped = true;
    }

    fn clear_search(&mut self) {
        self.search = None;
        if let Some(cancel) = self.starting_cancel.take() {
            cancel.store(true, std::sync::atomic::Ordering::Relaxed);
        }
        self.starting = None;
        self.completed = false;
        self.results.clear();
        self.icons.clear();
        self.pending_icons.clear();
        self.icon_generation = self.icon_generation.wrapping_add(1);
        if let Some(worker) = &self.icon_worker {
            worker.invalidate(self.icon_generation);
        }
        self.selected = None;
        self.reset_result_page();
        self.stopped = false;
    }

    fn reset_result_page(&mut self) {
        self.last_clicked_file = None;
        self.exact_count = 0;
        self.result_limit = LIMIT;
        self.next_hit = None;
    }

    fn receive_results(&mut self) -> bool {
        let Some(search) = &mut self.search else {
            return false;
        };
        if self.next_hit.is_some() || self.completed {
            return false;
        }
        let mut batch = Vec::new();
        for _ in 0..500 {
            match search.try_recv_hit() {
                Ok(hit) if self.results.len() + batch.len() == self.result_limit => {
                    // The extra hit distinguishes a full last page from a page with more results.
                    self.next_hit = Some(hit);
                    search.set_paused(true);
                    break;
                }
                Ok(hit) => batch.push(hit),
                Err(std::sync::mpsc::TryRecvError::Empty) => break,
                Err(std::sync::mpsc::TryRecvError::Disconnected) => {
                    self.completed = true;
                    break;
                }
            }
        }
        let changed = !batch.is_empty();
        self.append_hits(batch);
        changed
    }

    fn append_hits(&mut self, hits: impl IntoIterator<Item = (MatchKind, Entry)>) {
        let mut exact = Vec::new();
        for (kind, entry) in hits {
            if self.sort.is_none() && kind == MatchKind::Exact {
                exact.push(entry);
            } else {
                self.results.push(entry);
            }
        }
        if !exact.is_empty() {
            if let Some(selected) = &mut self.selected {
                if *selected >= self.exact_count {
                    *selected += exact.len();
                }
            }
            let boundary = self.exact_count;
            self.exact_count += exact.len();
            self.results.splice(boundary..boundary, exact);
        }
    }

    fn continue_search(&mut self) {
        if let Some(hit) = self.next_hit.take() {
            self.result_limit = self.result_limit.saturating_add(LIMIT);
            self.append_hits([hit]);
            if let Some(search) = &self.search {
                search.set_paused(false);
            }
        }
    }

    #[cfg(target_os = "linux")]
    fn catalog_ready(&mut self) -> bool {
        if self.catalog.is_some() {
            return true;
        }
        let receiver = self.catalog_loading.get_or_insert_with(|| {
            let (sender, receiver) = std::sync::mpsc::channel();
            std::thread::spawn(move || {
                let _ = sender.send(linux_apps::Catalog::load());
            });
            receiver
        });
        match receiver.try_recv() {
            Ok(catalog) => {
                self.catalog = Some(std::sync::Arc::new(catalog));
                self.catalog_loading = None;
                true
            }
            Err(std::sync::mpsc::TryRecvError::Disconnected) => {
                self.catalog_loading = None;
                self.changed = None;
                self.action_error = Some("Could not load the desktop application list".into());
                false
            }
            Err(std::sync::mpsc::TryRecvError::Empty) => false,
        }
    }

    fn update_ui(&mut self, ctx: &egui::Context) {
        #[cfg(target_os = "linux")]
        {
            let apps_mode = self.mode == Mode::Apps;
            let catalog = self.catalog.clone();
            let errors = self.action_error_sender.clone();
            self.update_ui_with_opener(ctx, &mut |path, reveal| {
                if apps_mode && !reveal {
                    if let Some(error) = catalog.as_ref().and_then(|apps| apps.launch(path).err()) {
                        let _ = errors.send(error);
                        ctx.request_repaint();
                    }
                } else {
                    open_linux_path(path, reveal, errors.clone(), ctx.clone());
                }
            });
        }
        #[cfg(windows)]
        if self.mode == Mode::Apps {
            let mut error = None;
            self.update_ui_with_opener(ctx, &mut |path, reveal| {
                if reveal {
                    open(path, true);
                } else if let Err(err) = launch_windows_app(path) {
                    error = Some(format!("Cannot launch {}: {err}", path.display()));
                }
            });
            if error.is_some() {
                self.action_error = error;
            }
            return;
        }
        #[cfg(not(target_os = "linux"))]
        self.update_ui_with_opener(ctx, &mut open);
    }

    fn update_ui_with_opener(&mut self, ctx: &egui::Context, open: &mut dyn FnMut(&Path, bool)) {
        #[cfg(any(target_os = "macos", target_os = "windows"))]
        if self
            .native_menu
            .as_ref()
            .is_some_and(|menu| menu.take_interface())
        {
            self.interface_open = true;
        }
        if self.interface_open && ctx.input(|i| i.key_pressed(Key::Escape)) {
            self.interface_open = false;
            return;
        }
        let interface_was_open = self.interface_open;
        if self.interface_open {
            let mut open = self.interface_open;
            let mut enabled = self.embedded_exe_icons;
            egui::Window::new("Interface")
                .open(&mut open)
                .show(ctx, |ui| {
                    ui.checkbox(&mut enabled, "Use embedded icons for Windows executables");
                });
            self.interface_open = open;
            if enabled != self.embedded_exe_icons {
                self.embedded_exe_icons = enabled;
                self.icons.retain(|path, _| !exe_icon::is_exe(path));
                self.pending_icons.clear();
                self.icon_generation = self.icon_generation.wrapping_add(1);
                if let Some(worker) = &self.icon_worker {
                    worker.invalidate(self.icon_generation);
                }
            }
        }
        if let Some(worker) = &self.icon_worker {
            while let Ok(response) = worker.receiver.try_recv() {
                if response.generation != self.icon_generation {
                    continue;
                }
                self.pending_icons.remove(&response.path);
                let icon = response.pixels.map(|pixels| {
                    ctx.load_texture(
                        response.path.to_string_lossy(),
                        egui::ColorImage::from_rgba_unmultiplied([32, 32], &pixels),
                        egui::TextureOptions::LINEAR,
                    )
                });
                self.icons.insert(response.path, icon);
            }
        }
        #[cfg(target_os = "macos")]
        let permissions_were_open = {
            if self
                .native_menu
                .as_ref()
                .is_some_and(|menu| menu.take_permissions())
            {
                self.permissions.open = true;
            }
            if self.permissions.open && ctx.input(|i| i.key_pressed(Key::Escape)) {
                self.permissions.open = false;
                return;
            }
            let was_open = self.permissions.open;
            if self.permissions.show(ctx) {
                self.refresh_after_permission_selection();
            }
            was_open
        };
        #[cfg(any(target_os = "macos", target_os = "windows"))]
        if self
            .native_menu
            .as_ref()
            .is_some_and(|menu| menu.take_stop())
        {
            self.stop_search();
        }
        if let Ok(error) = self.action_errors.try_recv() {
            self.action_error = Some(error);
        }
        if let Some(result) = self.action_result.as_ref().map(|rx| rx.try_recv()) {
            match result {
                Ok(result) => {
                    self.action_result = None;
                    if let Err(error) = result {
                        self.action_error = Some(error);
                    }
                }
                Err(std::sync::mpsc::TryRecvError::Disconnected) => {
                    self.action_result = None;
                    self.action_error = Some("Application chooser stopped unexpectedly".into());
                }
                Err(std::sync::mpsc::TryRecvError::Empty) => {}
            }
        }
        let error_was_open = self.action_error.is_some();
        if error_was_open {
            let mut dismiss = false;
            egui::Window::new("Unable to complete action")
                .collapsible(false)
                .show(ctx, |ui| {
                    ui.label(self.action_error.as_deref().unwrap_or_default());
                    if ui.button("OK").clicked() {
                        dismiss = true;
                    }
                });
            if dismiss {
                self.action_error = None;
            }
        }
        if !self.selector_open && ctx.input(|i| i.key_pressed(Key::Escape)) {
            ctx.send_viewport_cmd(egui::ViewportCommand::Close);
            return;
        }
        let ready = self
            .changed
            .is_some_and(|t| t.elapsed() >= Duration::from_millis(250));
        #[cfg(target_os = "linux")]
        let ready = ready && (self.mode != Mode::Apps || self.catalog_ready());
        if ready {
            self.changed = None;
            self.clear_search();
            let query = SearchQuery::parse(&self.query);
            let mode = self.mode;
            if !query.is_empty() || (mode == Mode::Apps && self.query.trim().is_empty()) {
                #[cfg(target_os = "linux")]
                let catalog = self.catalog.clone();
                #[cfg(target_os = "macos")]
                let additional_roots = self.permissions.roots();
                let (tx, rx) = std::sync::mpsc::sync_channel(1);
                let cancel = std::sync::Arc::new(std::sync::atomic::AtomicBool::new(false));
                self.starting_cancel = Some(cancel.clone());
                self.starting = Some(rx);
                std::thread::spawn(move || {
                    #[cfg(target_os = "linux")]
                    if let Some(apps) = catalog.filter(|_| mode == Mode::Apps) {
                        let hits = apps.search(&query, &cancel);
                        let _ = tx.send(Results::Apps(hits.into_iter()));
                        return;
                    }
                    #[cfg(feature = "ui-test-driver")]
                    let roots = std::env::var_os("DRILL_UI_TEST_ROOT")
                        .map(|p| vec![p.into()])
                        .unwrap_or_else(|| default_roots_with_cancel(&cancel));
                    #[cfg(not(feature = "ui-test-driver"))]
                    let roots = default_roots_with_cancel(&cancel);
                    #[cfg(target_os = "macos")]
                    let roots = {
                        let mut roots = roots;
                        roots.extend(additional_roots);
                        roots
                    };
                    let _ = tx.send(Results::Walk(Search::start_filtered(
                        query,
                        roots,
                        cancel,
                        mode.file_filter(),
                    )));
                });
            }
        }
        if let Some(result) = self.starting.as_ref().map(|starting| starting.try_recv()) {
            match result {
                Ok(search) => {
                    self.search = Some(search);
                    self.starting = None;
                    self.starting_cancel = None;
                }
                Err(std::sync::mpsc::TryRecvError::Disconnected) => {
                    self.starting = None;
                    self.starting_cancel = None;
                    self.action_error = Some("Search could not start".into());
                    ctx.request_repaint();
                }
                Err(std::sync::mpsc::TryRecvError::Empty) => {}
            }
        }
        let selected_before_batch = self.selected;
        let mut results_changed = self.receive_results();
        let title = if self.stopped {
            format!("Drill - {} items found - stopped", self.results.len())
        } else if self.next_hit.is_some() {
            format!(
                "Drill - {} results shown - more available",
                self.results.len()
            )
        } else if let Some(search) = &self.search {
            if self.completed {
                format!("Drill - {} items found - done", self.results.len())
            } else if let Some(pending) = search.directories_pending() {
                format!(
                    "Drill - {} items found - {} directories to scan",
                    self.results.len(),
                    pending
                )
            } else {
                format!("Drill - {} apps found", self.results.len())
            }
        } else if self.starting.is_some() {
            "Drill - starting search".into()
        } else {
            "Drill".into()
        };
        ctx.send_viewport_cmd(egui::ViewportCommand::Title(title));
        #[cfg(any(target_os = "macos", target_os = "windows"))]
        if let Some(menu) = &self.native_menu {
            menu.set_enabled(self.can_stop());
        }
        #[cfg(not(any(target_os = "macos", target_os = "windows")))]
        in_window_search_menu(ctx, self);
        #[cfg(target_os = "macos")]
        let background_input_allowed =
            !permissions_were_open && !interface_was_open && !self.interface_open;
        #[cfg(not(target_os = "macos"))]
        let background_input_allowed = !interface_was_open && !self.interface_open;
        let mut icon_budget = 4;
        let mut icons_pending = false;
        egui::CentralPanel::default().show(ctx, |ui| {
            let background_input_allowed = background_input_allowed && !error_was_open;
            if !background_input_allowed {
                ui.disable();
            }
            let old_mode = self.mode;
            let (response, selector) = ui.horizontal(|ui| {
                let combo_width = 76.0;
                let input_width = (ui.available_width() - combo_width - ui.spacing().item_spacing.x).max(1.0);
                let response = ui.add_sized(
                    [input_width, 38.0],
                    egui::TextEdit::singleline(&mut self.query)
                        .font(egui::FontId::proportional(24.0))
                        .hint_text("Search..."),
                );
                let selector = egui::ComboBox::from_id_salt("search_mode")
                    .width(combo_width)
                    .selected_text(self.mode.label())
                    .show_ui(ui, |ui| {
                        for mode in [Mode::Files, Mode::Apps] {
                            ui.selectable_value(&mut self.mode, mode, mode.label());
                        }
                    }).response;
                (response, selector)
            }).inner;
            let mode_changed = old_mode != self.mode;
            if self.focus_search || mode_changed {
                response.request_focus();
                self.focus_search = false;
            }
            let was_open = self.selector_open;
            self.selector_open = egui::ComboBox::is_open(ctx, selector.id);
            let background_input_allowed = background_input_allowed
                && !was_open && !self.selector_open && !selector.has_focus() && !mode_changed;
            if response.changed() || mode_changed {
                self.clear_search();
                #[cfg(target_os = "linux")]
                if mode_changed {
                    self.catalog = None;
                }
                self.changed = (self.mode == Mode::Apps || !self.query.trim().is_empty()).then(Instant::now);
            }
            let continued = self.next_hit.is_some() && ui.button("Continue searching").clicked();
            if continued {
                // egui buttons activate on Enter without consuming the key.
                ctx.input_mut(|input| input.consume_key(input.modifiers, Key::Enter));
                self.continue_search();
                results_changed = true;
            }
            let mut keyboard_selection_changed = self.selected != selected_before_batch;
            if background_input_allowed
                && ctx.input(|i| i.key_pressed(Key::ArrowDown))
                && !self.results.is_empty()
            {
                keyboard_selection_changed = true;
                self.selected = Some(
                    self.selected
                        .map_or(0, |n| (n + 1).min(self.results.len() - 1)),
                );
                response.surrender_focus();
            }
            if background_input_allowed && ctx.input(|i| i.key_pressed(Key::ArrowUp)) {
                keyboard_selection_changed = true;
                if let Some(n) = self.selected {
                    if n == 0 {
                        self.selected = None;
                        response.request_focus();
                    } else {
                        self.selected = Some(n - 1);
                    }
                }
            }
            let enter = background_input_allowed && !continued && ctx.input(|input| input.events.iter().any(|event|
                matches!(event, egui::Event::Key { key: Key::Enter, pressed: true, repeat: false, .. })));
            let mut result_focus = ctx.memory(|memory| memory.focused().is_none() || memory.has_focus(response.id));
            let mut row_menu_open = false;
            ui.separator();
            let total = ui.available_width();
            let (header, _) = ui.allocate_exact_size(
                egui::vec2(total, 20.0),
                egui::Sense::hover(),
            );
            let mut edge = header.left();
            let hit_widths = self.column_widths;
            for divider in 0..3 {
                edge += total * hit_widths[divider];
                let hit = egui::Rect::from_center_size(
                    egui::pos2(edge, header.center().y),
                    egui::vec2(8.0, header.height()),
                );
                let response = ui.interact(
                    hit,
                    ui.id().with(("column-divider", divider)),
                    egui::Sense::drag(),
                ).on_hover_cursor(egui::CursorIcon::ResizeHorizontal);
                let pointer_x = ctx.input(|input| {
                    if response.drag_stopped() {
                        input.events.iter().rev().find_map(|event| match event {
                            egui::Event::PointerButton { pos, button: egui::PointerButton::Primary, pressed: false, .. } => Some(pos.x),
                            _ => None,
                        }).or_else(|| input.pointer.latest_pos().map(|pos| pos.x))
                    } else {
                        input.pointer.latest_pos().map(|pos| pos.x)
                    }
                });
                if response.drag_started() {
                    if let Some(x) = ctx.input(|input| input.pointer.press_origin().map(|pos| pos.x)) {
                        self.column_drag = Some((divider, x, hit_widths));
                    }
                }
                match (response.dragged() || response.drag_stopped(), self.column_drag, pointer_x) {
                    (true, Some((active, start, original)), Some(x)) if active == divider => {
                        self.column_widths = original;
                        resize_columns(&mut self.column_widths, divider, x - start, total);
                    }
                    _ => {}
                }
                if response.drag_stopped() {
                    self.column_drag = None;
                }
            }
            let mut edge = header.left();
            for width in self.column_widths.iter().take(3) {
                edge += total * width;
                ui.painter().line_segment(
                    [egui::pos2(edge, header.top()), egui::pos2(edge, header.bottom())],
                    ui.visuals().widgets.noninteractive.bg_stroke,
                );
            }
            let widths = self.column_widths;
            let mut x = header.left();
            for (index, (name, column)) in [
                ("Name", SortColumn::Name),
                ("Path", SortColumn::Path),
                ("Size", SortColumn::Size),
                ("Date", SortColumn::Date),
            ].into_iter().enumerate() {
                let width = total * widths[index];
                let cell = egui::Rect::from_min_max(
                    egui::pos2(x + if index == 0 { 0.0 } else { 4.0 }, header.top()),
                    egui::pos2((x + width - if index == 3 { 0.0 } else { 4.0 }).max(x + 4.0), header.bottom()),
                );
                let response = ui.interact(cell, ui.id().with(("column-header", index)), egui::Sense::click());
                let painter = ui.painter().with_clip_rect(cell);
                painter.text(
                    egui::pos2(x + 4.0, header.center().y),
                    egui::Align2::LEFT_CENTER,
                    name,
                    egui::TextStyle::Body.resolve(ui.style()),
                    ui.visuals().text_color(),
                );
                if let Some((_, ascending)) = self.sort.filter(|(current, _)| *current == column) {
                    let center = egui::pos2(cell.right() - 9.0, cell.center().y);
                    let direction = if ascending { -1.0 } else { 1.0 };
                    painter.add(egui::Shape::convex_polygon(
                        vec![
                            center + egui::vec2(0.0, direction * 3.0),
                            center + egui::vec2(-4.0, -direction * 2.0),
                            center + egui::vec2(4.0, -direction * 2.0),
                        ],
                        ui.visuals().text_color(),
                        egui::Stroke::NONE,
                    ));
                }
                if response.clicked() {
                    let ascending = !matches!(self.sort, Some((current, true)) if current == column);
                    self.sort = Some((column, ascending));
                    results_changed = true;
                }
                x += width;
            }
            if results_changed {
                if let Some((column, ascending)) = self.sort {
                    let selected_path = self
                        .selected
                        .and_then(|i| self.results.get(i))
                        .map(|entry| entry.path.clone());
                    self.results.sort_by(|a, b| {
                        let order = compare_entries(a, b, column);
                        if ascending {
                            order
                        } else {
                            order.reverse()
                        }
                    });
                    let previous = self.selected;
                    self.selected = selected_path
                        .and_then(|path| self.results.iter().position(|entry| entry.path == path));
                    if self.selected != previous {
                        keyboard_selection_changed = true;
                    }
                }
            }
            ui.separator();
            let row_spacing = ui.spacing().item_spacing.y;
            let row_height = (RESULT_ROW_PITCH - row_spacing).max(RESULT_ICON_SIZE);
            let mut area = egui::ScrollArea::both().auto_shrink([false, false]);
            if keyboard_selection_changed {
                if let Some(selected) = self.selected {
                    let height = ui.available_height();
                    let stride = row_height + row_spacing;
                    let top = selected as f32 * stride;
                    let offset = if top < self.scroll_offset {
                        top
                    } else if top + row_height > self.scroll_offset + height {
                        (top + row_height - height).max(0.0)
                    } else {
                        self.scroll_offset
                    };
                    area = area.vertical_scroll_offset(offset);
                }
            }
            // egui counts double-clicks across widgets. A moving row must receive both clicks.
            let previous_click = if ctx.input(|input| input.pointer.any_click()) {
                self.last_clicked_file.take()
            } else {
                None
            };
            let scroll = area.show_rows(ui, row_height, self.results.len(), |ui, range| {
                for index in range {
                    let entry = &self.results[index];
                    let (_, rect) = ui.allocate_space(egui::vec2(total, row_height));
                    // Keep open menus and pending clicks attached to the same file as rows move.
                    let result = ui.interact(rect, ui.id().with(("result", &entry.path)), egui::Sense::click());
                    result_focus |= self.selected == Some(index) && result.has_focus();
                    row_menu_open |= result.context_menu_opened();
                    if result.clicked() || result.secondary_clicked() {
                        self.selected = Some(index);
                    }
                    if result.clicked_by(egui::PointerButton::Primary) {
                        if result.double_clicked() && previous_click.as_ref() == Some(&entry.path) {
                            open(&entry.path, false);
                        }
                        self.last_clicked_file = Some(entry.path.clone());
                    }
                    if self.selected == Some(index) {
                        ui.painter()
                            .rect_filled(rect, 0.0, ui.visuals().selection.bg_fill);
                    } else if index % 2 == 1 {
                        ui.painter()
                            .rect_filled(rect, 0.0, ui.visuals().faint_bg_color);
                    }
                    let values = [
                        entry.name.clone(),
                        entry
                            .path
                            .parent()
                            .unwrap_or(Path::new(""))
                            .to_string_lossy()
                            .into_owned(),
                        size(entry),
                        date(entry),
                    ];
                    let icon_pos = egui::pos2(rect.left() + 5.0, rect.center().y - RESULT_ICON_SIZE / 2.0);
                    let icon_rect = egui::Rect::from_min_size(icon_pos, egui::Vec2::splat(RESULT_ICON_SIZE));
                    if !self.icons.contains_key(&entry.path) {
                        let route = exe_icon::icon_route(
                            &entry.path,
                            entry.is_dir,
                            self.embedded_exe_icons,
                        );
                        if route != exe_icon::IconRoute::Platform {
                            if route != exe_icon::IconRoute::Decode {
                                self.icons.insert(entry.path.clone(), None);
                            } else if !self.pending_icons.contains(&entry.path) {
                                let worker = self.icon_worker.get_or_insert_with(|| {
                                    let worker = exe_icon::Worker::new();
                                    worker.invalidate(self.icon_generation);
                                    worker
                                });
                                match worker.request(
                                    self.icon_generation,
                                    entry.path.clone(),
                                    ctx.clone(),
                                ) {
                                    exe_icon::RequestState::Queued => {
                                        self.pending_icons.insert(entry.path.clone());
                                    }
                                    exe_icon::RequestState::Full => icons_pending = true,
                                    exe_icon::RequestState::Closed => {
                                        for path in self.pending_icons.drain() {
                                            self.icons.insert(path, None);
                                        }
                                        self.icons.insert(entry.path.clone(), None);
                                    }
                                }
                            }
                        } else if icon_budget > 0 {
                            icon_budget -= 1;
                            let path_label = entry.path.to_string_lossy();
                            let fallback = || file_icon_provider::get_file_icon(&entry.path, NATIVE_ICON_PIXELS).ok()
                                .and_then(|icon| platform_icon_texture(ctx, icon, &path_label));
                            #[cfg(target_os = "linux")]
                            let icon = if self.mode == Mode::Apps {
                                self.catalog.as_ref().and_then(|catalog| themed_icon_texture(ctx,
                                    catalog.icon_names(&entry.path).iter().map(String::as_str), &path_label))
                                    .or_else(fallback)
                            } else { fallback() };
                            #[cfg(not(target_os = "linux"))]
                            let icon = fallback();
                            self.icons.insert(entry.path.clone(), icon);
                        } else {
                            icons_pending = true;
                        }
                    }
                    let name_cell = egui::Rect::from_min_size(rect.min, egui::vec2(total * widths[0], row_height));
                    let painter = ui.painter().with_clip_rect(name_cell);
                    match self.icons.get(&entry.path) {
                        Some(Some(texture)) => {
                            painter.image(
                                texture.id(),
                                icon_rect,
                                egui::Rect::from_min_max(egui::Pos2::ZERO, egui::pos2(1.0, 1.0)),
                                egui::Color32::WHITE,
                            );
                        }
                        Some(None) => {
                            let type_icon = if !entry.is_dir && exe_icon::is_exe(&entry.path) {
                                self.exe_type_icon
                                    .get_or_insert_with(|| executable_type_icon(ctx))
                                    .as_ref()
                            } else {
                                None
                            };
                            if let Some(texture) = type_icon {
                                painter.image(
                                    texture.id(),
                                    icon_rect,
                                    egui::Rect::from_min_max(
                                        egui::Pos2::ZERO,
                                        egui::pos2(1.0, 1.0),
                                    ),
                                    egui::Color32::WHITE,
                                );
                            } else if entry.is_dir {
                                let color = egui::Color32::from_rgb(224, 174, 78);
                                painter.rect_filled(
                                    egui::Rect::from_min_size(
                                        icon_pos + egui::vec2(2.0, 5.0),
                                        egui::vec2(11.0, 6.0),
                                    ),
                                    1.0,
                                    color,
                                );
                                painter.rect_filled(
                                    egui::Rect::from_min_size(
                                        icon_pos + egui::vec2(2.0, 10.0),
                                        egui::vec2(26.0, 18.0),
                                    ),
                                    2.0,
                                    color,
                                );
                            } else {
                                painter.rect_filled(
                                    egui::Rect::from_min_size(
                                        icon_pos + egui::vec2(5.0, 4.0),
                                        egui::vec2(20.0, 24.0),
                                    ),
                                    1.0,
                                    egui::Color32::from_gray(190),
                                );
                            }
                        }
                        None => {}
                    }
                    if self.embedded_exe_icons
                        && !entry.is_dir
                        && exe_icon::is_exe(&entry.path)
                        && matches!(self.icons.get(&entry.path), Some(None))
                    {
                        result.clone().on_hover_text(
                            "Embedded icon unavailable. For cloud-only files, download the file, then edit the search to retry.",
                        );
                    }
                    let mut x = rect.left();
                    for (column, (value, fraction)) in values.into_iter().zip(widths).enumerate() {
                        let column_width = total * fraction;
                        let clip = egui::Rect::from_min_max(
                            egui::pos2(x, rect.top()),
                            egui::pos2(x + column_width - 4.0, rect.bottom()),
                        );
                        ui.painter().with_clip_rect(clip).text(
                            egui::pos2(if column == 0 { icon_rect.right() + 6.0 } else { x + 4.0 }, rect.center().y),
                            egui::Align2::LEFT_CENTER,
                            value,
                            egui::TextStyle::Body.resolve(ui.style()),
                            if self.selected == Some(index) {
                                ui.visuals().selection.stroke.color
                            } else {
                                ui.visuals().text_color()
                            },
                        );
                        x += column_width;
                    }
                    result.context_menu(|ui| {
                        if ui.button(if self.mode == Mode::Apps { "Launch" } else { "Open" }).clicked() {
                            open(&entry.path, false);
                            ui.close_menu();
                        }
                        if ui
                            .add_enabled(
                                self.action_result.is_none(),
                                egui::Button::new("Open with…"),
                            )
                            .clicked()
                        {
                            let path = entry.path.clone();
                            #[cfg(target_os = "linux")]
                            if let Err(error) = open_with(&path) {
                                self.action_error = Some(error);
                            }
                            #[cfg(not(target_os = "linux"))]
                            {
                                let (sender, receiver) = std::sync::mpsc::channel();
                                let context = ui.ctx().clone();
                                std::thread::spawn(move || {
                                    let _ = sender.send(open_with(&path));
                                    context.request_repaint();
                                });
                                self.action_result = Some(receiver);
                            }
                            ui.close_menu();
                        }
                        if icon_menu_button(ui, if cfg!(target_os = "linux") && self.mode == Mode::Apps { "Reveal launcher file" } else { "Reveal in file manager" }, MenuIcon::Folder) {
                            open(&entry.path, true);
                            ui.close_menu();
                        }
                        if icon_menu_button(ui, "Open terminal here", MenuIcon::Terminal) {
                            match open_terminal(terminal_directory(entry)) {
                                Ok(mut child) => {
                                    let sender = self.action_error_sender.clone();
                                    let context = ui.ctx().clone();
                                    std::thread::spawn(move || {
                                        let error = match child.wait() {
                                            Ok(status) if status.success() => None,
                                            Ok(status) => {
                                                Some(format!("Terminal exited with {status}"))
                                            }
                                            Err(error) => {
                                                Some(format!("Cannot wait for terminal: {error}"))
                                            }
                                        };
                                        if let Some(error) = error {
                                            let _ = sender.send(error);
                                            context.request_repaint();
                                        }
                                    });
                                }
                                Err(error) => self.action_error = Some(error),
                            }
                            ui.close_menu();
                        }
                        if ui.button("Copy Full Path").clicked() {
                            ui.ctx()
                                .copy_text(entry.path.to_string_lossy().into_owned());
                            ui.close_menu();
                        }
                        if ui.button("Copy Date").clicked() {
                            ui.ctx().copy_text(date(entry));
                            ui.close_menu();
                        }
                        if ui.button("Copy Size").clicked() {
                            ui.ctx().copy_text(size(entry));
                            ui.close_menu();
                        }
                    });
                }
            });
            self.scroll_offset = scroll.state.offset.y;
            if enter && result_focus && !row_menu_open {
                if let Some(entry) = self.selected.and_then(|index| self.results.get(index)) {
                    open(&entry.path, false);
                }
            }
        });
        #[cfg(feature = "ui-test-driver")]
        if let Some(path) = std::env::var_os("DRILL_UI_TEST_STATUS") {
            let inner = ctx.input(|input| input.viewport().inner_rect);
            let (x, y) = inner
                .map(|rect| (rect.min.x, rect.min.y))
                .unwrap_or((0.0, 0.0));
            let status = format!(
                "query={}\nresults={}\nselected={}\ndone={}\nsort={:?}\nx={}\ny={}\n",
                self.query,
                self.results
                    .iter()
                    .map(|entry| entry.name.as_str())
                    .collect::<Vec<_>>()
                    .join("|"),
                self.selected
                    .map_or_else(|| "none".into(), |n| n.to_string()),
                self.completed,
                self.sort,
                x,
                y
            );
            let _ = std::fs::write(path, status);
            ctx.request_repaint_after(Duration::from_millis(50));
        }
        if (self.search.is_some() && !self.completed && self.next_hit.is_none())
            || self.starting.is_some()
            || self.changed.is_some()
            || icons_pending
        {
            ctx.request_repaint_after(Duration::from_millis(30));
        }
    }

    #[cfg(target_os = "macos")]
    fn refresh_after_permission_selection(&mut self) {
        if (self.mode == Mode::Apps || !self.query.trim().is_empty()) && !self.stopped {
            self.changed = Some(Instant::now() - Duration::from_millis(250));
        }
    }
}
impl eframe::App for App {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        self.update_ui(ctx);
    }
    fn save(&mut self, storage: &mut dyn eframe::Storage) {
        storage.set_string("embedded_exe_icons", self.embedded_exe_icons.to_string());
    }
    fn persist_egui_memory(&self) -> bool {
        false
    }
}

fn main() -> eframe::Result {
    if std::env::args().any(|arg| arg == "--version") {
        println!("Drill {}", env!("CARGO_PKG_VERSION"));
        return Ok(());
    }
    #[cfg(target_os = "macos")]
    let icon_bytes: &[u8] = include_bytes!("assets/drill-macos.png");
    #[cfg(not(target_os = "macos"))]
    let icon_bytes: &[u8] = include_bytes!("assets/drill.png");
    let icon = image::load_from_memory(icon_bytes)
        .expect("embedded Drill icon must be valid PNG")
        .into_rgba8();
    let (width, height) = icon.dimensions();
    let icon = egui::IconData {
        rgba: icon.into_raw(),
        width,
        height,
    };
    let options = eframe::NativeOptions {
        #[cfg(feature = "ui-test-driver")]
        persistence_path: std::env::var_os("DRILL_UI_TEST_STATUS")
            .map(std::path::PathBuf::from)
            .and_then(|path| path.parent().map(|parent| parent.join("ui-settings.ron"))),
        viewport: egui::ViewportBuilder::default()
            .with_inner_size([960.0, 600.0])
            .with_icon(icon),
        ..Default::default()
    };
    eframe::run_native(
        "Drill",
        options,
        Box::new(|creation| {
            creation.egui_ctx.set_theme(egui::ThemePreference::System);
            let embedded_exe_icons = embedded_icons_setting(creation.storage);
            #[cfg(any(target_os = "macos", target_os = "windows"))]
            let app = App {
                native_menu: Some(native_menu::NativeMenu::new(creation)?),
                embedded_exe_icons,
                ..Default::default()
            };
            #[cfg(not(any(target_os = "macos", target_os = "windows")))]
            let app = App {
                embedded_exe_icons,
                ..Default::default()
            };
            Ok(Box::new(app))
        }),
    )
}

#[cfg(test)]
mod ui_tests {
    use super::*;
    use std::path::PathBuf;

    #[test]
    fn executable_icon_preference_defaults_on_and_round_trips() {
        use eframe::App as _;
        struct Memory(Option<String>);
        impl eframe::Storage for Memory {
            fn get_string(&self, _: &str) -> Option<String> {
                self.0.clone()
            }
            fn set_string(&mut self, _: &str, value: String) {
                self.0 = Some(value);
            }
            fn flush(&mut self) {}
        }
        let mut storage = Memory(None);
        assert!(embedded_icons_setting(Some(&storage)));
        let mut app = App {
            embedded_exe_icons: false,
            ..Default::default()
        };
        app.save(&mut storage);
        assert!(!embedded_icons_setting(Some(&storage)));
    }

    #[test]
    fn terminal_uses_folder_itself_or_file_parent_even_if_missing() {
        let mut item = entry("report ' spaces.txt", 1);
        item.path = PathBuf::from("/missing project/report ' spaces.txt");
        assert_eq!(terminal_directory(&item), Path::new("/missing project"));
        item.is_dir = true;
        assert_eq!(terminal_directory(&item), item.path);
        assert!(open_terminal(terminal_directory(&item)).is_err());
    }

    #[test]
    fn stop_revokes_pending_start_and_preserves_results() {
        use std::sync::{
            atomic::{AtomicBool, Ordering},
            Arc,
        };
        let (tx, rx) = std::sync::mpsc::sync_channel(1);
        let cancel = Arc::new(AtomicBool::new(false));
        let mut app = App {
            query: "kept".into(),
            results: vec![entry("kept", 1)],
            selected: Some(0),
            starting: Some(rx),
            starting_cancel: Some(cancel.clone()),
            ..Default::default()
        };
        app.stop_search();
        assert!(cancel.load(Ordering::Relaxed));
        assert!(app.stopped && !app.can_stop());
        assert_eq!(app.results[0].name, "kept");
        assert_eq!(app.selected, Some(0));
        let stale = Search::start_with_cancel("stale".into(), vec![], cancel);
        assert!(tx.send(Results::Walk(stale)).is_err());
        assert!(app.search.is_none());
    }

    #[test]
    fn stop_cancels_typing_delay() {
        let mut app = App {
            query: "test".into(),
            changed: Some(Instant::now()),
            ..Default::default()
        };
        assert!(app.can_stop());
        app.stop_search();
        assert!(!app.can_stop());
        assert!(app.stopped);
        assert_eq!(app.query, "test");
    }

    #[cfg(target_os = "macos")]
    #[test]
    fn permissions_window_blocks_background_search_input() {
        let ctx = egui::Context::default();
        let mut app = App {
            results: vec![entry("first", 1), entry("second", 2)],
            selected: Some(0),
            ..Default::default()
        };
        app.permissions.open = true;
        let _ = frame(
            &ctx,
            &mut app,
            vec![key(Key::ArrowDown), egui::Event::Text("unexpected".into())],
        );
        assert_eq!(app.selected, Some(0));
        assert!(app.query.is_empty());
    }

    #[cfg(target_os = "macos")]
    #[test]
    fn selecting_folder_refreshes_query_but_respects_stop() {
        let mut app = App {
            query: "report".into(),
            ..Default::default()
        };
        app.refresh_after_permission_selection();
        assert!(app.changed.is_some());
        app.changed = None;
        app.stopped = true;
        app.refresh_after_permission_selection();
        assert!(app.changed.is_none());
    }

    #[test]
    fn stop_discards_active_search_without_clearing_results() {
        let search = Search::start("kept".into(), vec![std::env::temp_dir()]);
        let mut app = App {
            query: "kept".into(),
            results: vec![entry("kept", 1)],
            selected: Some(0),
            search: Some(Results::Walk(search)),
            ..Default::default()
        };
        app.stop_search();
        assert!(app.search.is_none());
        assert_eq!(app.results.len(), 1);
        assert_eq!(app.selected, Some(0));
        let ctx = egui::Context::default();
        let _ = frame(&ctx, &mut app, vec![]);
        assert_eq!(app.results.len(), 1);
        app.changed = Some(Instant::now());
        assert!(app.can_stop(), "a subsequent query can be started");
    }

    #[test]
    fn search_menu_stop_cancels_pending_search() {
        let ctx = egui::Context::default();
        let mut app = App {
            query: "kept".into(),
            changed: Some(Instant::now()),
            results: vec![entry("kept", 1)],
            ..Default::default()
        };
        let render = |app: &mut App, events| {
            let _ = ctx.run(
                egui::RawInput {
                    screen_rect: Some(egui::Rect::from_min_size(
                        egui::Pos2::ZERO,
                        egui::vec2(800.0, 600.0),
                    )),
                    events,
                    ..Default::default()
                },
                |ctx| in_window_search_menu(ctx, app),
            );
        };
        render(&mut app, vec![]);
        for point in [egui::pos2(20.0, 10.0), egui::pos2(20.0, 38.0)] {
            for pressed in [true, false] {
                render(
                    &mut app,
                    vec![
                        egui::Event::PointerMoved(point),
                        egui::Event::PointerButton {
                            pos: point,
                            button: egui::PointerButton::Primary,
                            pressed,
                            modifiers: egui::Modifiers::NONE,
                        },
                    ],
                );
            }
            render(&mut app, vec![]);
        }
        assert!(app.stopped);
        assert_eq!(app.results[0].name, "kept");
        assert!(!app.can_stop());
    }

    #[test]
    fn icon_menu_row_highlights_on_hover() {
        let ctx = egui::Context::default();
        let draw = |events| {
            ctx.run(
                egui::RawInput {
                    events,
                    ..Default::default()
                },
                |ctx| {
                    egui::CentralPanel::default().show(ctx, |ui| {
                        icon_menu_button(ui, "Open terminal here", MenuIcon::Terminal);
                    });
                },
            )
        };
        let idle = draw(vec![]);
        let hovered = draw(vec![egui::Event::PointerMoved(egui::pos2(15.0, 15.0))]);
        assert!(
            hovered.shapes.len() > idle.shapes.len(),
            "hover should paint the row background"
        );
    }

    #[test]
    fn icon_menu_row_clicks_work_on_icon_and_right_edge() {
        for x in [15.0, 185.0] {
            let ctx = egui::Context::default();
            let point = egui::pos2(x, 15.0);
            let mut clicked = false;
            let _ = ctx.run(egui::RawInput::default(), |ctx| {
                egui::CentralPanel::default().show(ctx, |ui| {
                    icon_menu_button(ui, "Open terminal here", MenuIcon::Terminal);
                });
            });
            for pressed in [true, false] {
                let events = vec![
                    egui::Event::PointerMoved(point),
                    egui::Event::PointerButton {
                        pos: point,
                        button: egui::PointerButton::Primary,
                        pressed,
                        modifiers: egui::Modifiers::NONE,
                    },
                ];
                let _ = ctx.run(
                    egui::RawInput {
                        events,
                        ..Default::default()
                    },
                    |ctx| {
                        egui::CentralPanel::default().show(ctx, |ui| {
                            clicked |=
                                icon_menu_button(ui, "Open terminal here", MenuIcon::Terminal);
                        });
                    },
                );
            }
            assert!(clicked, "row was not clickable at x={x}");
        }
    }

    fn frame(ctx: &egui::Context, app: &mut App, events: Vec<egui::Event>) -> egui::FullOutput {
        let input = egui::RawInput {
            screen_rect: Some(egui::Rect::from_min_size(
                egui::Pos2::ZERO,
                egui::vec2(800.0, 600.0),
            )),
            events,
            ..Default::default()
        };
        ctx.run(input, |ctx| app.update_ui(ctx))
    }
    fn key(key: Key) -> egui::Event {
        egui::Event::Key {
            key,
            physical_key: None,
            pressed: true,
            repeat: false,
            modifiers: egui::Modifiers::NONE,
        }
    }
    fn entry(name: &str, size: u64) -> Entry {
        Entry {
            path: PathBuf::from(format!("/nonexistent/{name}")),
            name: name.into(),
            size: Some(size),
            modified: None,
            is_dir: false,
        }
    }
    #[test]
    fn late_exact_hits_preserve_selection_and_respect_manual_sort() {
        let mut app = App::default();
        app.append_hits([(MatchKind::Partial, entry("rom.exe.bak", 1))]);
        app.selected = Some(0);
        app.append_hits([
            (MatchKind::Partial, entry("old-rom.exe", 2)),
            (MatchKind::Exact, entry("ROM.EXE", 3)),
        ]);
        assert_eq!(app.results[0].name, "ROM.EXE");
        assert_eq!(app.results[app.selected.unwrap()].name, "rom.exe.bak");
        // An explicit size ordering already has these entries in the correct order.
        let mut app = App {
            sort: Some((SortColumn::Size, true)),
            ..App::default()
        };
        app.append_hits([
            (MatchKind::Partial, entry("rom.exe.bak", 1)),
            (MatchKind::Exact, entry("rom.exe", 2)),
        ]);
        assert_eq!(app.results[0].name, "rom.exe.bak");
    }

    fn text_position(output: &egui::FullOutput, label: &str) -> egui::Pos2 {
        output
            .shapes
            .iter()
            .find_map(|shape| match &shape.shape {
                egui::Shape::Text(text) if text.galley.text() == label => {
                    Some(text.pos + text.galley.size() / 2.0)
                }
                _ => None,
            })
            .unwrap_or_else(|| panic!("missing label: {label}"))
    }

    #[test]
    fn context_menu_copies_original_path_after_late_exact_hit() {
        let ctx = egui::Context::default();
        let mut app = App::default();
        let original = entry("rom.exe.bak", 1);
        let path = original.path.to_string_lossy().into_owned();
        app.append_hits([(MatchKind::Partial, original)]);
        let pos = text_position(&frame(&ctx, &mut app, vec![]), "rom.exe.bak");
        let button = |pos, button, pressed| {
            vec![
                egui::Event::PointerMoved(pos),
                egui::Event::PointerButton {
                    pos,
                    button,
                    pressed,
                    modifiers: egui::Modifiers::NONE,
                },
            ]
        };
        for pressed in [true, false] {
            let _ = frame(
                &ctx,
                &mut app,
                button(pos, egui::PointerButton::Secondary, pressed),
            );
        }
        app.append_hits([(MatchKind::Exact, entry("rom.exe", 2))]);
        let _ = frame(&ctx, &mut app, vec![]);
        let copy = text_position(&frame(&ctx, &mut app, vec![]), "Copy Full Path");
        let _ = frame(
            &ctx,
            &mut app,
            button(copy, egui::PointerButton::Primary, true),
        );
        let output = frame(
            &ctx,
            &mut app,
            button(copy, egui::PointerButton::Primary, false),
        );
        assert!(
            output
                .platform_output
                .commands
                .iter()
                .any(|cmd| matches!(cmd, egui::OutputCommand::CopyText(value) if value == &path)),
            "clipboard output: {:?}",
            output.platform_output.commands
        );
    }

    #[test]
    fn menu_and_error_dialog_own_enter_over_a_selected_app() {
        let ctx = egui::Context::default();
        let mut app = App {
            mode: Mode::Apps,
            ..Default::default()
        };
        let file = entry("Example.exe", 1);
        let expected = file.path.to_string_lossy().into_owned();
        app.append_hits([(MatchKind::Exact, file)]);
        let render = |app: &mut App, events| {
            let input = egui::RawInput {
                screen_rect: Some(egui::Rect::from_min_size(
                    egui::Pos2::ZERO,
                    egui::vec2(800.0, 600.0),
                )),
                events,
                ..Default::default()
            };
            ctx.run(input, |ctx| {
                app.update_ui_with_opener(ctx, &mut |_, _| {
                    panic!("Enter on a menu or dialog launched the selected application")
                })
            })
        };
        let point = text_position(&render(&mut app, vec![]), "Example.exe");
        for pressed in [true, false] {
            render(
                &mut app,
                vec![
                    egui::Event::PointerMoved(point),
                    egui::Event::PointerButton {
                        pos: point,
                        button: egui::PointerButton::Secondary,
                        pressed,
                        modifiers: egui::Modifiers::NONE,
                    },
                ],
            );
        }
        assert_eq!(app.selected, Some(0));
        render(&mut app, vec![]);
        let key_event = |key, pressed| egui::Event::Key {
            key,
            physical_key: None,
            pressed,
            repeat: false,
            modifiers: egui::Modifiers::NONE,
        };
        let tab_to = |app: &mut App, label: &str| {
            for _ in 0..40 {
                let mut focused = false;
                for pressed in [true, false] {
                    let output = render(app, vec![key_event(Key::Tab, pressed)]);
                    focused |= output.platform_output.events.iter().any(|event| matches!(
                        event, egui::output::OutputEvent::FocusGained(info) if info.label.as_deref() == Some(label)
                    ));
                }
                if focused {
                    return;
                }
            }
            panic!("{label} should be reachable with Tab");
        };
        tab_to(&mut app, "Copy Full Path");
        let output = render(&mut app, vec![key(Key::Enter)]);
        assert!(output
            .platform_output
            .commands
            .iter()
            .any(|cmd| matches!(cmd, egui::OutputCommand::CopyText(path) if path == &expected)));
        app.action_error = Some("Launch failed".into());
        render(&mut app, vec![key_event(Key::Enter, false)]);
        tab_to(&mut app, "OK");
        render(&mut app, vec![key(Key::Enter)]);
        assert!(app.action_error.is_none());
    }

    #[test]
    fn both_clicks_must_target_the_same_file_to_open_it() {
        for insert_exact in [false, true] {
            let ctx = egui::Context::default();
            let mut app = App::default();
            app.append_hits([(MatchKind::Partial, entry("rom.exe.bak", 2))]);
            let mut opened = Vec::new();
            let mut render = |app: &mut App, events| {
                let input = egui::RawInput {
                    screen_rect: Some(egui::Rect::from_min_size(
                        egui::Pos2::ZERO,
                        egui::vec2(800.0, 600.0),
                    )),
                    events,
                    ..Default::default()
                };
                ctx.run(input, |ctx| {
                    app.update_ui_with_opener(ctx, &mut |path, _| opened.push(path.to_owned()))
                })
            };
            let pos = text_position(&render(&mut app, vec![]), "rom.exe.bak");
            for click in 0..2 {
                if click == 1 && insert_exact {
                    app.append_hits([(MatchKind::Exact, entry("rom.exe", 1))]);
                    let _ = render(&mut app, vec![]);
                }
                for pressed in [true, false] {
                    let _ = render(
                        &mut app,
                        vec![
                            egui::Event::PointerMoved(pos),
                            egui::Event::PointerButton {
                                pos,
                                button: egui::PointerButton::Primary,
                                pressed,
                                modifiers: egui::Modifiers::NONE,
                            },
                        ],
                    );
                }
            }
            if insert_exact {
                assert!(opened.is_empty(), "unexpected open: {opened:?}");
            } else {
                assert_eq!(opened, vec![entry("rom.exe.bak", 2).path]);
            }
        }
    }

    #[test]
    fn switching_scope_keeps_text_and_cancels_previous_results() {
        let ctx = egui::Context::default();
        let mut app = App {
            query: "calculator".into(),
            results: vec![entry("calculator.txt", 2)],
            next_hit: Some((MatchKind::Partial, entry("old", 1))),
            selected: Some(0),
            ..App::default()
        };
        let click = |app: &mut App, pos| {
            for pressed in [true, false] {
                let _ = frame(
                    &ctx,
                    app,
                    vec![
                        egui::Event::PointerMoved(pos),
                        egui::Event::PointerButton {
                            pos,
                            button: egui::PointerButton::Primary,
                            pressed,
                            modifiers: egui::Modifiers::NONE,
                        },
                    ],
                );
            }
            frame(&ctx, app, vec![])
        };
        let output = frame(&ctx, &mut app, vec![]);
        let files = text_position(&output, "Files");
        assert!(files.x > 680.0, "scope must be on the right");
        let popup = click(&mut app, files);
        let apps = text_position(&popup, "Apps");
        let cancel = std::sync::Arc::new(std::sync::atomic::AtomicBool::new(false));
        app.starting_cancel = Some(cancel.clone());
        let _ = click(&mut app, apps);
        assert_eq!(app.mode.label(), "Apps");
        assert_eq!(app.query, "calculator");
        assert!(cancel.load(std::sync::atomic::Ordering::Relaxed));
        assert!(app.results.is_empty() && app.next_hit.is_none() && app.selected.is_none());
        assert!(app.changed.is_some());

        // An empty query browses Apps but returns Files to its idle screen.
        app.query.clear();
        let button = text_position(&frame(&ctx, &mut app, vec![]), "Apps");
        let popup = click(&mut app, button);
        let _ = click(&mut app, text_position(&popup, "Files"));
        assert_eq!(app.mode.label(), "Files");
        assert!(app.changed.is_none());
        let button = text_position(&frame(&ctx, &mut app, vec![]), "Files");
        let popup = click(&mut app, button);
        let _ = click(&mut app, text_position(&popup, "Apps"));
        assert!(app.changed.is_some());
    }

    #[test]
    fn enter_on_continue_admits_and_ranks_the_next_hit_and_consumes_the_shortcut() {
        let ctx = egui::Context::default();
        let mut app = App {
            results: vec![entry("rom.exe.bak", 2)],
            next_hit: Some((MatchKind::Exact, entry("rom.exe", 1))),
            ..App::default()
        };
        let _ = frame(&ctx, &mut app, vec![]);
        // The scope selector is between the search field and Continue in tab order.
        for _ in 0..2 {
            let _ = frame(&ctx, &mut app, vec![key(Key::Tab)]);
            let _ = frame(
                &ctx,
                &mut app,
                vec![egui::Event::Key {
                    key: Key::Tab,
                    physical_key: None,
                    pressed: false,
                    repeat: false,
                    modifiers: egui::Modifiers::NONE,
                }],
            );
        }
        let _ = frame(&ctx, &mut app, vec![key(Key::Enter)]);
        assert!(app.next_hit.is_none());
        assert_eq!(app.results[0].name, "rom.exe");
        assert!(!ctx.input(|input| input.key_pressed(Key::Enter)));
    }

    #[test]
    fn full_last_page_finishes_and_continue_delivers_each_remaining_file_once() {
        for count in [2, 520] {
            let root = tempfile::tempdir().unwrap();
            for n in 0..count {
                std::fs::write(root.path().join(format!("item-{n}")), []).unwrap();
            }
            let mut app = App {
                search: Some(Results::Walk(Search::start(
                    "item".into(),
                    vec![root.path().to_owned()],
                ))),
                result_limit: 2,
                ..App::default()
            };
            let deadline = Instant::now() + Duration::from_secs(10);
            let poll = |app: &mut App| {
                while !app.completed && app.next_hit.is_none() {
                    app.receive_results();
                    assert!(Instant::now() < deadline, "search stalled");
                    std::thread::yield_now();
                }
            };
            poll(&mut app);
            assert_eq!(app.results.len(), 2);
            if count == 2 {
                assert!(app.completed && app.next_hit.is_none());
                continue;
            }
            assert!(app.can_stop() && !app.completed);
            assert!(!app.receive_results(), "a paused search consumed hits");
            let ctx = egui::Context::default();
            let output = frame(&ctx, &mut app, vec![]);
            let pos = text_position(&output, "Continue searching");
            for pressed in [true, false] {
                let _ = frame(
                    &ctx,
                    &mut app,
                    vec![
                        egui::Event::PointerMoved(pos),
                        egui::Event::PointerButton {
                            pos,
                            button: egui::PointerButton::Primary,
                            pressed,
                            modifiers: egui::Modifiers::NONE,
                        },
                    ],
                );
            }
            assert!(app.next_hit.is_none());
            poll(&mut app);
            assert!(app.completed);
            let names: std::collections::HashSet<_> =
                app.results.iter().map(|e| e.name.as_str()).collect();
            assert_eq!(app.results.len(), count);
            assert_eq!(names.len(), count);
        }
    }

    fn assert_result_loads_embedded_icon(path: PathBuf) {
        let ctx = egui::Context::default();
        let mut result = entry("program.exe", 1);
        result.path = path.clone();
        let mut app = App {
            results: vec![result],
            ..Default::default()
        };
        let deadline = Instant::now() + Duration::from_secs(10);
        loop {
            let output = frame(&ctx, &mut app, vec![]);
            if let Some(icon) = app.icons.get(&path) {
                let icon = icon.as_ref().expect("the row used the fallback icon");
                let uploaded = output
                    .textures_delta
                    .set
                    .iter()
                    .find(|(id, _)| *id == icon.id())
                    .expect("embedded icon texture was not uploaded");
                let egui::ImageData::Color(image) = &uploaded.1.image else {
                    panic!("unexpected icon texture format")
                };
                assert_eq!(image.pixels[0], egui::Color32::from_rgb(0, 255, 0));
                let (bounds, clip) = output
                    .shapes
                    .iter()
                    .find_map(|shape| match &shape.shape {
                        egui::Shape::Mesh(mesh) if mesh.texture_id == icon.id() => {
                            Some((mesh.calc_bounds(), shape.clip_rect))
                        }
                        _ => None,
                    })
                    .expect("row did not draw the embedded icon");
                assert_eq!(bounds.size(), egui::vec2(32.0, 32.0));
                assert!(clip.contains_rect(bounds));
                let filename = output
                    .shapes
                    .iter()
                    .find_map(|shape| match &shape.shape {
                        egui::Shape::Text(text) if text.galley.text() == "program.exe" => {
                            Some(text.pos)
                        }
                        _ => None,
                    })
                    .expect("row did not draw the filename");
                assert!((filename.x - bounds.right() - 6.0).abs() < 1.0);
                return;
            }
            assert!(Instant::now() < deadline, "icon did not arrive");
            std::thread::sleep(Duration::from_millis(10));
        }
    }
    #[test]
    fn visible_executable_row_loads_embedded_icon() {
        use std::io::Write;
        let mut file = tempfile::Builder::new().suffix(".exe").tempfile().unwrap();
        file.write_all(include_bytes!("../tests/fixtures/icon-pe32.exe"))
            .unwrap();
        assert_result_loads_embedded_icon(file.path().to_path_buf());
    }
    #[test]
    fn typing_starts_debounce_and_clearing_resets_the_window() {
        let ctx = egui::Context::default();
        let mut app = App::default();
        let _ = frame(&ctx, &mut app, vec![]);
        let _ = frame(&ctx, &mut app, vec![egui::Event::Text("a".into())]);
        assert_eq!(app.query, "a");
        assert!(app.changed.is_some());
        app.results.push(entry("old", 0));
        let _ = frame(&ctx, &mut app, vec![key(Key::Backspace)]);
        assert!(app.query.is_empty());
        assert!(app.results.is_empty());
        assert!(app.search.is_none());
        assert!(app.changed.is_none());
    }
    #[test]
    fn escape_requests_window_close() {
        let ctx = egui::Context::default();
        let mut app = App::default();
        let out = frame(&ctx, &mut app, vec![key(Key::Escape)]);
        assert!(out.viewport_output[&egui::ViewportId::ROOT]
            .commands
            .iter()
            .any(|c| matches!(c, egui::ViewportCommand::Close)));
    }
    #[test]
    fn keyboard_selection_scrolls_and_up_returns_to_search() {
        let ctx = egui::Context::default();
        let mut app = App {
            results: (0..100).map(|i| entry(&format!("entry-{i}"), i)).collect(),
            selected: Some(60),
            ..Default::default()
        };
        let _ = frame(&ctx, &mut app, vec![key(Key::ArrowDown)]);
        assert_eq!(app.selected, Some(61));
        // A row this far down must use egui's height plus item spacing;
        // a 25 px-only stride leaves it well below the viewport.
        assert!(app.scroll_offset > 1200.0);
        app.selected = Some(0);
        let _ = frame(&ctx, &mut app, vec![key(Key::ArrowUp)]);
        assert_eq!(app.selected, None);
    }
    #[test]
    fn dragging_column_divider_resizes_without_sorting() {
        let ctx = egui::Context::default();
        let mut app = App {
            results: vec![entry("zeta", 1), entry("alpha", 2)],
            selected: Some(0),
            ..Default::default()
        };
        let _ = frame(&ctx, &mut app, vec![]);
        let start = egui::pos2(
            8.0 + 784.0 * 0.35,
            66.0 + if cfg!(target_os = "linux") { 22.0 } else { 0.0 },
        );
        let end = start + egui::vec2(50.0, 0.0);
        let button = |pos, pressed| egui::Event::PointerButton {
            pos,
            button: egui::PointerButton::Primary,
            pressed,
            modifiers: egui::Modifiers::NONE,
        };
        let _ = frame(
            &ctx,
            &mut app,
            vec![egui::Event::PointerMoved(start - egui::vec2(70.0, 0.0))],
        );
        let _ = frame(
            &ctx,
            &mut app,
            vec![egui::Event::PointerMoved(start), button(start, true)],
        );
        assert_eq!(app.column_widths, [0.35, 0.35, 0.1, 0.2]);
        let _ = frame(&ctx, &mut app, vec![egui::Event::PointerMoved(end)]);
        let release = end + egui::vec2(10.0, 0.0);
        let _ = frame(
            &ctx,
            &mut app,
            vec![
                egui::Event::PointerMoved(release),
                button(release, false),
                egui::Event::PointerMoved(release + egui::vec2(20.0, 0.0)),
            ],
        );
        assert!((app.column_widths[0] - (0.35 + 60.0 / 784.0)).abs() < 0.001);
        assert!(app.column_widths[0] > 0.40, "{:?}", app.column_widths);
        assert!(app.column_widths[1] < 0.30);
        assert_eq!(app.sort, None);
        assert_eq!(app.selected, Some(0));
        let header = egui::pos2(20.0, start.y);
        let _ = frame(
            &ctx,
            &mut app,
            vec![egui::Event::PointerMoved(header), button(header, true)],
        );
        let _ = frame(&ctx, &mut app, vec![button(header, false)]);
        assert_eq!(app.sort, Some((SortColumn::Name, true)));
        assert_eq!(app.results[0].name, "alpha");
    }
    #[test]
    fn column_resize_is_bounded_even_in_narrow_windows() {
        for total in [100.0, 800.0] {
            let mut widths = [0.35, 0.35, 0.1, 0.2];
            for divider in 0..3 {
                for delta in [-10_000.0, 10_000.0] {
                    resize_columns(&mut widths, divider, delta, total);
                    assert!(widths.iter().all(|width| *width >= 0.0));
                    assert!((widths.iter().sum::<f32>() - 1.0).abs() < 0.0001);
                }
            }
        }
        for total in [400.0, 482.0] {
            for delta in [-1.0, 0.0, 1.0] {
                let mut widths = [0.35, 0.35, 0.1, 0.2];
                resize_columns(&mut widths, 2, delta, total);
                let movement = (widths[2] - 0.1) * total;
                assert!(movement.abs() <= 1.001, "unexpected jump: {movement}");
                assert!(movement * delta >= 0.0);
                if delta != 0.0 {
                    assert!(movement * delta > 0.0, "divider did not move");
                }
            }
        }
    }
    #[test]
    fn clicking_header_toggles_sort_order() {
        let ctx = egui::Context::default();
        let mut app = App {
            results: vec![entry("zeta", 1), entry("alpha", 2)],
            ..Default::default()
        };
        let _ = frame(&ctx, &mut app, vec![]);
        let point = egui::pos2(
            20.0,
            66.0 + if cfg!(target_os = "linux") { 22.0 } else { 0.0 },
        );
        let click = |pressed| egui::Event::PointerButton {
            pos: point,
            button: egui::PointerButton::Primary,
            pressed,
            modifiers: egui::Modifiers::NONE,
        };
        let _ = frame(
            &ctx,
            &mut app,
            vec![egui::Event::PointerMoved(point), click(true)],
        );
        let _ = frame(&ctx, &mut app, vec![click(false)]);
        assert_eq!(app.sort, Some((SortColumn::Name, true)));
        assert_eq!(app.results[0].name, "alpha");
        let _ = frame(&ctx, &mut app, vec![click(true)]);
        let _ = frame(&ctx, &mut app, vec![click(false)]);
        assert_eq!(app.sort, Some((SortColumn::Name, false)));
        assert_eq!(app.results[0].name, "zeta");
    }
    #[test]
    fn sorting_compares_values_and_has_deterministic_ties() {
        let a = entry("zeta", 1);
        let b = entry("Alpha", 5);
        assert_eq!(
            compare_entries(&a, &b, SortColumn::Name),
            std::cmp::Ordering::Greater
        );
        assert_eq!(
            compare_entries(&a, &b, SortColumn::Size),
            std::cmp::Ordering::Less
        );
        assert_eq!(
            compare_entries(&a, &a, SortColumn::Date),
            std::cmp::Ordering::Equal
        );
    }
}
