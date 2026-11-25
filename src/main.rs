#![cfg_attr(target_os = "windows", windows_subsystem = "windows")]
#![deny(unsafe_code)]
use chrono::{DateTime, Local};
use drill_core::{default_roots_with_cancel, Entry, Search};
use eframe::egui::{self, Key, RichText};
use std::path::Path;
use std::time::{Duration, Instant};
#[cfg(any(target_os = "macos", target_os = "windows"))]
mod native_menu;
#[cfg(target_os = "macos")]
mod permissions;

const LIMIT: usize = 10_000;
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
struct App {
    query: String,
    changed: Option<Instant>,
    search: Option<Search>,
    starting: Option<std::sync::mpsc::Receiver<Search>>,
    starting_cancel: Option<std::sync::Arc<std::sync::atomic::AtomicBool>>,
    completed: bool,
    results: Vec<Entry>,
    selected: Option<usize>,
    limited: bool,
    stopped: bool,
    focus_search: bool,
    scroll_offset: f32,
    icons: std::collections::HashMap<std::path::PathBuf, Option<egui::TextureHandle>>,
    sort: Option<(SortColumn, bool)>,
    action_error: Option<String>,
    action_result: Option<std::sync::mpsc::Receiver<Result<(), String>>>,
    terminal_sender: std::sync::mpsc::Sender<String>,
    terminal_errors: std::sync::mpsc::Receiver<String>,
    #[cfg(any(target_os = "macos", target_os = "windows"))]
    native_menu: Option<native_menu::NativeMenu>,
    #[cfg(target_os = "macos")]
    permissions: permissions::Permissions,
}
impl Default for App {
    fn default() -> Self {
        let (terminal_sender, terminal_errors) = std::sync::mpsc::channel();
        Self {
            query: String::new(),
            changed: None,
            search: None,
            starting: None,
            starting_cancel: None,
            completed: false,
            results: Vec::new(),
            selected: None,
            limited: false,
            stopped: false,
            focus_search: true,
            scroll_offset: 0.0,
            icons: std::collections::HashMap::new(),
            sort: None,
            action_error: None,
            action_result: None,
            terminal_sender,
            terminal_errors,
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
        });
    });
}
impl App {
    fn can_stop(&self) -> bool {
        self.changed.is_some()
            || self.starting.is_some()
            || (self.search.is_some() && !self.completed && !self.limited)
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
        self.stopped = true;
    }

    fn update_ui(&mut self, ctx: &egui::Context) {
        #[cfg(target_os = "macos")]
        {
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
            self.permissions.show(ctx);
        }
        #[cfg(any(target_os = "macos", target_os = "windows"))]
        if self
            .native_menu
            .as_ref()
            .is_some_and(|menu| menu.take_stop())
        {
            self.stop_search();
        }
        if let Ok(error) = self.terminal_errors.try_recv() {
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
        if self.action_error.is_some() {
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
        if ctx.input(|i| i.key_pressed(Key::Escape)) {
            ctx.send_viewport_cmd(egui::ViewportCommand::Close);
            return;
        }
        if self
            .changed
            .is_some_and(|t| t.elapsed() >= Duration::from_millis(250))
        {
            self.changed = None;
            self.search = None;
            if let Some(cancel) = self.starting_cancel.take() {
                cancel.store(true, std::sync::atomic::Ordering::Relaxed);
            }
            self.starting = None;
            self.completed = false;
            self.results.clear();
            self.icons.clear();
            self.selected = None;
            self.limited = false;
            self.stopped = false;
            if !self.query.trim().is_empty() {
                let query = self.query.clone();
                #[cfg(target_os = "macos")]
                let additional_roots = self.permissions.roots();
                let (tx, rx) = std::sync::mpsc::sync_channel(1);
                let cancel = std::sync::Arc::new(std::sync::atomic::AtomicBool::new(false));
                self.starting_cancel = Some(cancel.clone());
                self.starting = Some(rx);
                std::thread::spawn(move || {
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
                    let _ = tx.send(Search::start_with_cancel(query, roots, cancel));
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
        let mut results_changed = false;
        if let Some(search) = &self.search {
            for _ in 0..500 {
                match search.try_recv() {
                    Ok(entry) => {
                        self.results.push(entry);
                        results_changed = true;
                        if self.results.len() >= LIMIT {
                            search.stop();
                            self.limited = true;
                            break;
                        }
                    }
                    Err(std::sync::mpsc::TryRecvError::Disconnected) => {
                        self.completed = true;
                        break;
                    }
                    Err(std::sync::mpsc::TryRecvError::Empty) => break,
                }
            }
        }
        if self.limited {
            self.search = None;
        }
        let title = if self.stopped {
            format!("Drill - {} items found - stopped", self.results.len())
        } else if self.limited {
            format!("Drill - {}+ items found, search stopped", LIMIT)
        } else if let Some(search) = &self.search {
            if self.completed {
                format!("Drill - {} items found - done", self.results.len())
            } else {
                format!(
                    "Drill - {} items found - {} directories to scan",
                    self.results.len(),
                    search.pending()
                )
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
        let background_input_allowed = !self.permissions.open;
        #[cfg(not(target_os = "macos"))]
        let background_input_allowed = true;
        let mut icon_budget = 4;
        let mut icons_pending = false;
        egui::CentralPanel::default().show(ctx, |ui| {
            if !background_input_allowed {
                ui.disable();
            }
            let response = ui.add_sized(
                [ui.available_width(), 38.0],
                egui::TextEdit::singleline(&mut self.query)
                    .font(egui::FontId::proportional(24.0))
                    .hint_text("Search..."),
            );
            if self.focus_search {
                response.request_focus();
                self.focus_search = false;
            }
            if response.changed() {
                self.search = None;
                if let Some(cancel) = self.starting_cancel.take() {
                    cancel.store(true, std::sync::atomic::Ordering::Relaxed);
                }
                self.starting = None;
                self.completed = false;
                self.results.clear();
                self.icons.clear();
                self.selected = None;
                self.limited = false;
                self.stopped = false;
                self.changed = if self.query.trim().is_empty() {
                    None
                } else {
                    Some(Instant::now())
                };
            }
            let mut keyboard_selection_changed = false;
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
            if background_input_allowed && ctx.input(|i| i.key_pressed(Key::Enter)) {
                if let Some(entry) = self.selected.and_then(|n| self.results.get(n)) {
                    open(&entry.path, false);
                }
            }
            ui.separator();
            let widths = [0.35, 0.35, 0.1, 0.2];
            let total = ui.available_width();
            ui.horizontal(|ui| {
                for ((name, column), fraction) in [
                    ("Name", SortColumn::Name),
                    ("Path", SortColumn::Path),
                    ("Size", SortColumn::Size),
                    ("Date", SortColumn::Date),
                ]
                .into_iter()
                .zip(widths)
                {
                    let label =
                        egui::Label::new(RichText::new(name).strong()).sense(egui::Sense::click());
                    let response = ui.add_sized([total * fraction - 8.0, 20.0], label);
                    if let Some((current, ascending)) =
                        self.sort.filter(|(current, _)| *current == column)
                    {
                        let _ = current;
                        let center =
                            egui::pos2(response.rect.right() - 9.0, response.rect.center().y);
                        let direction = if ascending { -1.0 } else { 1.0 };
                        ui.painter().add(egui::Shape::convex_polygon(
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
                        let ascending =
                            !matches!(self.sort, Some((current, true)) if current == column);
                        self.sort = Some((column, ascending));
                        results_changed = true;
                    }
                }
            });
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
            let mut area = egui::ScrollArea::both().auto_shrink([false, false]);
            if keyboard_selection_changed {
                if let Some(selected) = self.selected {
                    let height = ui.available_height();
                    let stride = 25.0 + ui.spacing().item_spacing.y;
                    let top = selected as f32 * stride;
                    let offset = if top < self.scroll_offset {
                        top
                    } else if top + 25.0 > self.scroll_offset + height {
                        (top + 25.0 - height).max(0.0)
                    } else {
                        self.scroll_offset
                    };
                    area = area.vertical_scroll_offset(offset);
                }
            }
            let scroll = area.show_rows(ui, 25.0, self.results.len(), |ui, range| {
                for index in range {
                    let entry = &self.results[index];
                    let (rect, result) =
                        ui.allocate_exact_size(egui::vec2(total, 25.0), egui::Sense::click());
                    if result.clicked() || result.secondary_clicked() {
                        self.selected = Some(index);
                    }
                    if result.double_clicked() {
                        open(&entry.path, false);
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
                    let icon_pos = egui::pos2(rect.left() + 3.0, rect.center().y - 10.0);
                    if !self.icons.contains_key(&entry.path) {
                        if icon_budget > 0 {
                            icon_budget -= 1;
                            let icon = file_icon_provider::get_file_icon(&entry.path, 24)
                                .ok()
                                .and_then(|icon| {
                                    let pixels =
                                        (icon.width as usize).checked_mul(icon.height as usize)?;
                                    let rgba = if icon.pixels.len() == pixels * 4 {
                                        icon.pixels
                                    } else if icon.pixels.len() == pixels * 3 {
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
                                    // AppKit and Windows shell bitmaps use premultiplied alpha;
                                    // GTK pixbufs use straight alpha.
                                    #[cfg(any(target_os = "macos", target_os = "windows"))]
                                    let image = egui::ColorImage::from_rgba_premultiplied(
                                        dimensions, &rgba,
                                    );
                                    #[cfg(not(any(target_os = "macos", target_os = "windows")))]
                                    let image =
                                        egui::ColorImage::from_rgba_unmultiplied(dimensions, &rgba);
                                    Some(ctx.load_texture(
                                        entry.path.to_string_lossy(),
                                        image,
                                        egui::TextureOptions::LINEAR,
                                    ))
                                });
                            self.icons.insert(entry.path.clone(), icon);
                        } else {
                            icons_pending = true;
                        }
                    }
                    let painter = ui.painter().with_clip_rect(rect);
                    match self.icons.get(&entry.path) {
                        Some(Some(texture)) => {
                            painter.image(
                                texture.id(),
                                egui::Rect::from_min_size(icon_pos, egui::vec2(20.0, 20.0)),
                                egui::Rect::from_min_max(egui::Pos2::ZERO, egui::pos2(1.0, 1.0)),
                                egui::Color32::WHITE,
                            );
                        }
                        Some(None) => {
                            if entry.is_dir {
                                let color = egui::Color32::from_rgb(224, 174, 78);
                                painter.rect_filled(
                                    egui::Rect::from_min_size(
                                        icon_pos + egui::vec2(1.0, 3.0),
                                        egui::vec2(7.0, 4.0),
                                    ),
                                    1.0,
                                    color,
                                );
                                painter.rect_filled(
                                    egui::Rect::from_min_size(
                                        icon_pos + egui::vec2(1.0, 6.0),
                                        egui::vec2(16.0, 11.0),
                                    ),
                                    2.0,
                                    color,
                                );
                            } else {
                                painter.rect_filled(
                                    egui::Rect::from_min_size(
                                        icon_pos + egui::vec2(3.0, 3.0),
                                        egui::vec2(12.0, 15.0),
                                    ),
                                    1.0,
                                    egui::Color32::from_gray(190),
                                );
                            }
                        }
                        None => {}
                    }
                    let mut x = rect.left();
                    for (column, (value, fraction)) in values.into_iter().zip(widths).enumerate() {
                        let column_width = total * fraction;
                        let clip = egui::Rect::from_min_max(
                            egui::pos2(x, rect.top()),
                            egui::pos2(x + column_width - 4.0, rect.bottom()),
                        );
                        ui.painter().with_clip_rect(clip).text(
                            egui::pos2(x + if column == 0 { 29.0 } else { 4.0 }, rect.center().y),
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
                        if ui.button("Open").clicked() {
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
                        if icon_menu_button(ui, "Reveal in file manager", MenuIcon::Folder) {
                            open(&entry.path, true);
                            ui.close_menu();
                        }
                        if icon_menu_button(ui, "Open terminal here", MenuIcon::Terminal) {
                            match open_terminal(terminal_directory(entry)) {
                                Ok(mut child) => {
                                    let sender = self.terminal_sender.clone();
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
        if (self.search.is_some() && !self.completed)
            || self.starting.is_some()
            || self.changed.is_some()
            || icons_pending
        {
            ctx.request_repaint_after(Duration::from_millis(30));
        }
    }
}
impl eframe::App for App {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        self.update_ui(ctx);
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
            #[cfg(any(target_os = "macos", target_os = "windows"))]
            let app = App {
                native_menu: Some(native_menu::NativeMenu::new(creation)?),
                ..Default::default()
            };
            #[cfg(not(any(target_os = "macos", target_os = "windows")))]
            let app = App::default();
            Ok(Box::new(app))
        }),
    )
}

#[cfg(test)]
mod ui_tests {
    use super::*;
    use std::path::PathBuf;

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
        assert!(tx.send(stale).is_err());
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

    #[test]
    fn stop_discards_active_search_without_clearing_results() {
        let search = Search::start("kept".into(), vec![std::env::temp_dir()]);
        let mut app = App {
            query: "kept".into(),
            results: vec![entry("kept", 1)],
            selected: Some(0),
            search: Some(search),
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
