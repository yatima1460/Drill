#![cfg_attr(target_os = "windows", windows_subsystem = "windows")]
#![deny(unsafe_code)]
use chrono::{DateTime, Local};
#[cfg(not(windows))]
use drill_core::default_roots_with_cancel;
#[cfg(any(not(windows), test, feature = "ui-test-driver"))]
use drill_core::Search;
use drill_core::{Entry, MatchKind, SearchQuery};
use eframe::egui::{self, Key};
use std::path::Path;
use std::time::{Duration, Instant};
mod appearance;
mod appimage_icon;
mod exe_icon;
mod result_emoji;
mod result_order;
mod search_mode;
mod syntax_help;
use search_mode::{Mode, Results};
#[cfg(target_os = "linux")]
mod linux_apps;
#[cfg(any(target_os = "macos", target_os = "windows"))]
mod native_menu;
#[cfg(target_os = "macos")]
mod permissions;

const LIMIT: usize = 10_000;
fn embedded_icons_setting(storage: Option<&dyn eframe::Storage>, key: &str) -> bool {
    storage
        .and_then(|storage| storage.get_string(key))
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
    prepared: Option<SearchQuery>,
    query_error: Option<String>,
    changed: Option<Instant>,
    mode: Mode,
    selector_open: bool,
    syntax_open: bool,
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
    emoji: result_emoji::EmojiCache,
    icon_worker: Option<exe_icon::Worker>,
    pending_icons: std::collections::HashSet<std::path::PathBuf>,
    exe_type_icon: Option<Option<egui::TextureHandle>>,
    icon_generation: u64,
    embedded_exe_icons: bool,
    embedded_appimage_icons: bool,
    appimage_type_icon: Option<Option<egui::TextureHandle>>,
    interface_open: bool,
    appearance: egui::ThemePreference,
    #[cfg(target_os = "linux")]
    desktop_theme: Option<appearance::linux::DesktopTheme>,
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
            prepared: None,
            query_error: None,
            changed: None,
            mode: Mode::Files,
            selector_open: false,
            syntax_open: false,
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
            emoji: result_emoji::EmojiCache::default(),
            icon_worker: None,
            pending_icons: Default::default(),
            exe_type_icon: None,
            icon_generation: 0,
            embedded_exe_icons: true,
            embedded_appimage_icons: true,
            appimage_type_icon: None,
            interface_open: false,
            appearance: egui::ThemePreference::System,
            #[cfg(target_os = "linux")]
            desktop_theme: None,
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
fn executable_type_icon(ctx: &egui::Context, sample_name: &str) -> Option<egui::TextureHandle> {
    // Ask the OS about a private, empty sample; never pass it the untrusted executable.
    let sample = tempfile::Builder::new()
        .suffix(sample_name)
        .tempfile()
        .ok()?;
    let icon = file_icon_provider::get_file_icon(sample.path(), NATIVE_ICON_PIXELS).ok()?;
    platform_icon_texture(ctx, icon, sample_name)
}
#[cfg(target_os = "linux")]
fn executable_type_icon(ctx: &egui::Context, sample_name: &str) -> Option<egui::TextureHandle> {
    use gtk::prelude::*;
    if !gtk::is_initialized() {
        gtk::init().ok()?;
    }
    let (content_type, _) = gtk::gio::content_type_guess(Some(Path::new(sample_name)), None);
    let icon = gtk::gio::content_type_get_icon(&content_type);
    let themed = icon.dynamic_cast_ref::<gtk::gio::ThemedIcon>()?;
    themed_icon_texture(
        ctx,
        themed.names().iter().map(|name| name.as_str()),
        sample_name,
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

#[cfg(windows)]
#[allow(unsafe_code)]
fn with_shell_sta(action: impl FnOnce() -> Result<(), String>) -> Result<(), String> {
    use windows_sys::Win32::System::Com::{
        CoInitializeEx, CoUninitialize, COINIT_APARTMENTTHREADED,
    };

    struct Apartment;
    impl Drop for Apartment {
        fn drop(&mut self) {
            // SAFETY: this guard stays on the thread where initialization succeeded.
            unsafe { CoUninitialize() };
        }
    }
    // SAFETY: both shell actions call this on a fresh worker thread.
    let initialized = unsafe { CoInitializeEx(std::ptr::null(), COINIT_APARTMENTTHREADED as u32) };
    if initialized < 0 {
        return Err(format!(
            "Cannot initialize Windows shell (0x{:08x})",
            initialized as u32
        ));
    }
    let _apartment = Apartment;
    action()
}

#[cfg(all(windows, test))]
#[test]
fn shell_worker_balances_sta_after_failed_action() {
    use windows_sys::Win32::System::Com::{CoGetApartmentType, APTTYPE_MAINSTA, APTTYPE_STA};

    #[allow(unsafe_code)]
    fn apartment() -> Result<(i32, i32), i32> {
        let (mut kind, mut qualifier) = (0, 0);
        // SAFETY: each output points to an initialized integer for the duration of the call.
        let result = unsafe { CoGetApartmentType(&mut kind, &mut qualifier) };
        if result < 0 {
            Err(result)
        } else {
            Ok((kind, qualifier))
        }
    }

    std::thread::spawn(|| {
        let before = apartment();
        let result = with_shell_sta(|| {
            assert!(matches!(
                apartment().unwrap().0,
                APTTYPE_STA | APTTYPE_MAINSTA
            ));
            Err(String::from("test action failed"))
        });
        assert_eq!(result, Err(String::from("test action failed")));
        assert_eq!(apartment(), before);
    })
    .join()
    .unwrap();
}

#[cfg(windows)]
#[allow(unsafe_code)]
fn open_with(path: &Path) -> Result<(), String> {
    use std::os::windows::ffi::OsStrExt;
    use windows_sys::Win32::UI::Shell::{SHOpenWithDialog, OAIF_EXEC, OPENASINFO};
    let wide: Vec<u16> = path.as_os_str().encode_wide().chain(Some(0)).collect();
    let info = OPENASINFO {
        pcszFile: wide.as_ptr(),
        pcszClass: std::ptr::null(),
        oaifInFlags: OAIF_EXEC,
    };
    with_shell_sta(|| {
        // SAFETY: the NUL-terminated filename and OPENASINFO remain alive throughout the call.
        let result = unsafe { SHOpenWithDialog(std::ptr::null_mut(), &info) };
        if result >= 0 || result as u32 == 0x8007_04c7 {
            Ok(())
        } else {
            Err(format!("Open with failed (0x{:08x})", result as u32))
        }
    })
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
            ui.menu_button("Help", |ui| {
                if ui.button("Syntax").clicked() {
                    app.syntax_open = true;
                    ui.close_menu();
                }
            });
        });
    });
}
impl App {
    fn can_stop(&self) -> bool {
        self.changed.is_some()
            || self.prepared.is_some()
            || self.starting.is_some()
            || (self.search.is_some() && !self.completed)
    }

    fn stop_search(&mut self) {
        if !self.can_stop() {
            return;
        }
        self.changed = None;
        self.prepared = None;
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
        self.prepared = None;
        self.query_error = None;
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
            let (inserted, selected) =
                result_order::exact_batch(self.exact_count, self.selected, exact.len());
            self.results.splice(inserted.start..inserted.start, exact);
            self.exact_count = inserted.end;
            self.selected = selected;
        }
    }

    fn continue_search(&mut self) {
        if let Some(hit) = self.next_hit.take() {
            self.result_limit = self.result_limit.saturating_add(LIMIT);
            self.append_hits([hit]);
            if let Some(search) = &mut self.search {
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
                self.prepared = None;
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
        let native_requests = self
            .native_menu
            .as_ref()
            .map(|menu| menu.take_requests())
            .unwrap_or_default();
        #[cfg(any(target_os = "macos", target_os = "windows"))]
        if native_requests.syntax {
            self.syntax_open = true;
        }
        let syntax_was_open = self.syntax_open;
        if self.syntax_open && syntax_help::show(ctx) {
            self.syntax_open = false;
            self.focus_search = true;
        }
        #[cfg(any(target_os = "macos", target_os = "windows"))]
        if native_requests.interface {
            self.interface_open = true;
        }
        if self.interface_open && ctx.input(|i| i.key_pressed(Key::Escape)) {
            self.interface_open = false;
            return;
        }
        let interface_was_open = self.interface_open;
        if self.interface_open {
            let mut open = self.interface_open;
            let mut exe_enabled = self.embedded_exe_icons;
            let mut appimage_enabled = self.embedded_appimage_icons;
            egui::Window::new("Interface")
                .open(&mut open)
                .show(ctx, |ui| {
                    appearance::controls(ui, &mut self.appearance);
                    ui.checkbox(
                        &mut exe_enabled,
                        "Use embedded icons for Windows executables",
                    );
                    ui.checkbox(&mut appimage_enabled, "Use embedded icons for AppImages");
                });
            self.interface_open = open;
            let exe_changed = exe_enabled != self.embedded_exe_icons;
            let appimage_changed = appimage_enabled != self.embedded_appimage_icons;
            if exe_changed || appimage_changed {
                self.embedded_exe_icons = exe_enabled;
                self.embedded_appimage_icons = appimage_enabled;
                self.icons.retain(|path, _| {
                    !(exe_changed && exe_icon::is_exe(path)
                        || appimage_changed && exe_icon::is_appimage(path))
                });
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
            if native_requests.permissions {
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
        if native_requests.stop {
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
        if !syntax_was_open && !self.selector_open && ctx.input(|i| i.key_pressed(Key::Escape)) {
            ctx.send_viewport_cmd(egui::ViewportCommand::Close);
            return;
        }
        let ready = self
            .changed
            .is_some_and(|t| t.elapsed() >= Duration::from_millis(250));
        if ready {
            self.changed = None;
            self.clear_search();
            let query = SearchQuery::parse(&self.query);
            if let Some(error) = query.error() {
                self.query_error = Some(error.to_owned());
            } else if !query.is_empty() || (self.mode == Mode::Apps && self.query.trim().is_empty())
            {
                self.prepared = Some(query);
            }
        }
        let ready = self.prepared.is_some();
        #[cfg(target_os = "linux")]
        let ready = ready && (self.mode != Mode::Apps || self.catalog_ready());
        if ready {
            let mode = self.mode;
            if let Some(query) = self.prepared.take() {
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
                    if let Some(root) = std::env::var_os("DRILL_UI_TEST_ROOT") {
                        let search = Search::start_filtered(
                            query,
                            vec![root.into()],
                            cancel,
                            mode.file_filter(),
                        );
                        let _ = tx.send(Results::Walk(search));
                        return;
                    }
                    #[cfg(windows)]
                    let results = Results::Windows(drill_core::WindowsSearch::start(
                        query,
                        cancel,
                        mode.file_filter(),
                    ));
                    #[cfg(not(windows))]
                    let results = {
                        let roots = default_roots_with_cancel(&cancel);
                        #[cfg(target_os = "macos")]
                        let roots = {
                            let mut roots = roots;
                            roots.extend(additional_roots);
                            roots
                        };
                        Results::Walk(Search::start_filtered(
                            query,
                            roots,
                            cancel,
                            mode.file_filter(),
                        ))
                    };
                    let _ = tx.send(results);
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
            } else if cfg!(target_os = "linux") && self.mode == Mode::Apps {
                format!("Drill - {} apps found", self.results.len())
            } else {
                format!(
                    "Drill - {} items found - discovering search roots",
                    self.results.len()
                )
            }
        } else if self.prepared.is_some() || self.starting.is_some() {
            "Drill - starting search".into()
        } else {
            "Drill".into()
        };
        ctx.send_viewport_cmd(egui::ViewportCommand::Title(title));
        #[cfg(any(target_os = "macos", target_os = "windows"))]
        if let Some(menu) = &self.native_menu {
            if syntax_was_open && !self.syntax_open {
                menu.syntax_closed();
            }
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
            let background_input_allowed = background_input_allowed && !error_was_open && !syntax_was_open && !self.syntax_open;
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
                ).on_hover_text("Search names, use a wildcard like *.md, or start with glob:, regex: or fuzzy:");
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
            if background_input_allowed && (self.focus_search || mode_changed) {
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
            if let Some(error) = &self.query_error {
                ui.colored_label(ui.visuals().error_fg_color, error);
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
                    let is_appimage = exe_icon::is_appimage(&entry.path);
                    let embedded_enabled = if is_appimage { self.embedded_appimage_icons } else { self.embedded_exe_icons };
                    if !self.icons.contains_key(&entry.path) {
                        let route = exe_icon::icon_route(
                            &entry.path,
                            entry.is_dir,
                            embedded_enabled,
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
                            let type_icon = if !entry.is_dir && is_appimage {
                                self.appimage_type_icon
                                    .get_or_insert_with(|| executable_type_icon(ctx, "sample.AppImage"))
                                    .as_ref()
                            } else if !entry.is_dir && exe_icon::is_exe(&entry.path) {
                                self.exe_type_icon
                                    .get_or_insert_with(|| executable_type_icon(ctx, "sample.exe"))
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
                    if embedded_enabled
                        && !entry.is_dir
                        && (is_appimage || exe_icon::is_exe(&entry.path))
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
                        self.emoji.paint(
                            &ui.painter().with_clip_rect(clip),
                            egui::pos2(if column == 0 { icon_rect.right() + 6.0 } else { x + 4.0 }, rect.center().y),
                            &value,
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
            || self.prepared.is_some()
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
    #[cfg(any(target_os = "linux", windows))]
    fn raw_input_hook(&mut self, ctx: &egui::Context, input: &mut egui::RawInput) {
        #[cfg(target_os = "linux")]
        if let Some(desktop) = &self.desktop_theme {
            input.system_theme = desktop.current().or(input.system_theme);
        }
        if input.system_theme != ctx.system_theme() {
            appearance::update_window(ctx, self.appearance, input.system_theme);
        }
    }

    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        self.update_ui(ctx);
    }
    fn save(&mut self, storage: &mut dyn eframe::Storage) {
        appearance::save(storage, self.appearance);
        storage.set_string("embedded_exe_icons", self.embedded_exe_icons.to_string());
        storage.set_string(
            "embedded_appimage_icons",
            self.embedded_appimage_icons.to_string(),
        );
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
            let appearance = appearance::load(creation.storage);
            appearance::apply(&creation.egui_ctx, appearance);
            let embedded_exe_icons = embedded_icons_setting(creation.storage, "embedded_exe_icons");
            let embedded_appimage_icons =
                embedded_icons_setting(creation.storage, "embedded_appimage_icons");
            #[cfg(any(target_os = "macos", target_os = "windows"))]
            let app = App {
                native_menu: Some(native_menu::NativeMenu::new(creation)?),
                appearance,
                embedded_exe_icons,
                embedded_appimage_icons,
                ..Default::default()
            };
            #[cfg(not(any(target_os = "macos", target_os = "windows")))]
            let app = App {
                #[cfg(target_os = "linux")]
                desktop_theme: Some(appearance::linux::DesktopTheme::new(
                    creation.egui_ctx.clone(),
                )),
                appearance,
                embedded_exe_icons,
                embedded_appimage_icons,
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

    #[derive(Default)]
    struct Memory(std::collections::HashMap<String, String>);
    impl eframe::Storage for Memory {
        fn get_string(&self, key: &str) -> Option<String> {
            self.0.get(key).cloned()
        }
        fn set_string(&mut self, key: &str, value: String) {
            self.0.insert(key.into(), value);
        }
        fn flush(&mut self) {}
    }

    #[test]
    fn embedded_icon_preferences_default_on_and_round_trip_independently() {
        use eframe::App as _;
        let mut storage = Memory::default();
        eframe::Storage::set_string(&mut storage, "embedded_exe_icons", "false".into());
        assert!(embedded_icons_setting(
            Some(&storage),
            "embedded_appimage_icons"
        ));
        assert!(!embedded_icons_setting(
            Some(&storage),
            "embedded_exe_icons"
        ));
        let mut app = App {
            embedded_appimage_icons: false,
            ..Default::default()
        };
        app.save(&mut storage);
        assert!(!embedded_icons_setting(
            Some(&storage),
            "embedded_appimage_icons"
        ));
        assert!(embedded_icons_setting(Some(&storage), "embedded_exe_icons"));
    }

    #[test]
    fn interface_appearance_clicks_apply_and_restore_the_selected_mode() {
        use eframe::App as _;
        use egui::{SystemTheme, Theme, ThemePreference};

        let ctx = egui::Context::default();
        let mut storage = Memory::default();
        assert_eq!(appearance::load(Some(&storage)), ThemePreference::System);
        eframe::Storage::set_string(&mut storage, "appearance", "invalid".into());
        let mut app = App {
            interface_open: true,
            appearance: appearance::load(Some(&storage)),
            ..Default::default()
        };
        assert_eq!(app.appearance, ThemePreference::System);
        let draw = |app: &mut App, events, system| {
            let mut input = frame_input(events);
            input.system_theme = Some(system);
            ctx.run(input, |ctx| app.update_ui(ctx))
        };
        let _ = draw(&mut app, vec![], Theme::Light);
        for (label, preference, native, system, expected) in [
            (
                "Dark",
                ThemePreference::Dark,
                SystemTheme::Dark,
                Theme::Light,
                Theme::Dark,
            ),
            (
                "Light",
                ThemePreference::Light,
                SystemTheme::Light,
                Theme::Dark,
                Theme::Light,
            ),
            (
                "Auto",
                ThemePreference::System,
                if cfg!(target_os = "linux") {
                    SystemTheme::Dark
                } else {
                    SystemTheme::SystemDefault
                },
                Theme::Dark,
                Theme::Dark,
            ),
        ] {
            let point = text_position(&draw(&mut app, vec![], system), label);
            let click = |pressed| pointer_events(point, egui::PointerButton::Primary, pressed);
            let _ = draw(&mut app, click(true), system);
            let output = draw(&mut app, click(false), system);
            assert_eq!(app.appearance, preference);
            assert!(output.viewport_output[&egui::ViewportId::ROOT]
                .commands
                .iter()
                .any(
                    |cmd| matches!(cmd, egui::ViewportCommand::SetTheme(theme) if *theme == native)
                ));
            let _ = draw(&mut app, vec![], system);
            assert_eq!(ctx.style().visuals.dark_mode, expected == Theme::Dark);
            app.save(&mut storage);
            assert_eq!(appearance::load(Some(&storage)), preference);
        }
        let _ = draw(&mut app, vec![], Theme::Light);
        assert!(!ctx.style().visuals.dark_mode);
    }

    #[cfg(target_os = "linux")]
    #[test]
    fn unsuccessful_linux_opener_reports_target_and_exit_status() {
        use std::os::unix::fs::PermissionsExt;

        const CHILD: &str = "DRILL_TEST_FAILED_OPENER";
        if std::env::var_os(CHILD).is_some() {
            let target = Path::new("/example/folder with spaces");
            let (errors, receiver) = std::sync::mpsc::channel();
            open_linux_path(target, false, errors, egui::Context::default());
            let error = receiver.recv_timeout(Duration::from_secs(5)).unwrap();
            assert!(error.contains(&target.display().to_string()), "{error}");
            assert!(error.contains("exit status: 4"), "{error}");
            return;
        }

        // Isolate PATH so parallel UI tests use their usual desktop environment.
        let bin = tempfile::tempdir().unwrap();
        let opener = bin.path().join("xdg-open");
        std::fs::write(&opener, "#!/bin/sh\nexit 4\n").unwrap();
        std::fs::set_permissions(&opener, std::fs::Permissions::from_mode(0o700)).unwrap();
        let output = std::process::Command::new(std::env::current_exe().unwrap())
            .args([
                "--exact",
                "ui_tests::unsuccessful_linux_opener_reports_target_and_exit_status",
            ])
            .env("PATH", bin.path())
            .env(CHILD, "1")
            .output()
            .unwrap();
        assert!(
            output.status.success() && String::from_utf8_lossy(&output.stdout).contains("1 passed"),
            "{output:?}"
        );
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
    fn streamed_exact_executable_renders_sorted_and_preserves_selection() {
        let root = tempfile::tempdir().unwrap();
        std::fs::write(root.path().join("Demo.EXE"), b"file").unwrap();
        let (tx, rx) = std::sync::mpsc::sync_channel(1);
        let mut app = App {
            starting: Some(rx),
            sort: Some((SortColumn::Name, true)),
            ..App::default()
        };
        app.append_hits([(MatchKind::Partial, entry("z-demo.exe", 1))]);
        app.selected = Some(0);
        let walk = Search::start("demo.exe".into(), vec![root.path().to_owned()]);
        assert!(tx.send(Results::Walk(walk)).is_ok());
        let ctx = egui::Context::default();
        let deadline = Instant::now() + Duration::from_secs(5);
        loop {
            let output = frame(&ctx, &mut app, vec![]);
            if app.results.len() == 2 {
                text_position(&output, "Demo.EXE");
                break;
            }
            assert!(Instant::now() < deadline, "result never reached the UI");
            std::thread::yield_now();
        }
        assert_eq!(app.results[0].name, "Demo.EXE");
        assert_eq!(app.results[app.selected.unwrap()].name, "z-demo.exe");
        app.stop_search();
        assert!(app.starting.is_none());
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
            let _ = ctx.run(frame_input(events), |ctx| in_window_search_menu(ctx, app));
        };
        render(&mut app, vec![]);
        for point in [egui::pos2(20.0, 10.0), egui::pos2(20.0, 38.0)] {
            for pressed in [true, false] {
                render(
                    &mut app,
                    pointer_events(point, egui::PointerButton::Primary, pressed),
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
                let events = pointer_events(point, egui::PointerButton::Primary, pressed);
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

    fn pointer_events(
        pos: egui::Pos2,
        button: egui::PointerButton,
        pressed: bool,
    ) -> Vec<egui::Event> {
        vec![
            egui::Event::PointerMoved(pos),
            egui::Event::PointerButton {
                pos,
                button,
                pressed,
                modifiers: egui::Modifiers::NONE,
            },
        ]
    }

    fn frame_input(events: Vec<egui::Event>) -> egui::RawInput {
        egui::RawInput {
            screen_rect: Some(egui::Rect::from_min_size(
                egui::Pos2::ZERO,
                egui::vec2(800.0, 600.0),
            )),
            events,
            ..Default::default()
        }
    }

    fn frame(ctx: &egui::Context, app: &mut App, events: Vec<egui::Event>) -> egui::FullOutput {
        ctx.run(frame_input(events), |ctx| app.update_ui(ctx))
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
    fn emoji_filenames_paint_colored_clusters_inside_their_columns() {
        let ctx = egui::Context::default();
        let mut app = App::default();
        let name = "Notes 😭🥀.txt";
        let mut result = entry(name, 0);
        result.path = PathBuf::from("work👩🏽‍💻").join(name);
        app.icons.insert(result.path.clone(), None);
        app.results.push(result);
        app.selected = Some(0);
        let output = frame(&ctx, &mut app, vec![]);
        let mut emoji = Vec::new();
        for clipped in &output.shapes {
            let egui::Shape::Mesh(mesh) = &clipped.shape else {
                continue;
            };
            let Some((_, delta)) = output
                .textures_delta
                .set
                .iter()
                .find(|(id, _)| *id == mesh.texture_id)
            else {
                continue;
            };
            let egui::ImageData::Color(image) = &delta.image else {
                continue;
            };
            if image.size == [72, 72] {
                assert!(mesh
                    .vertices
                    .iter()
                    .all(|v| v.color == egui::Color32::WHITE));
                let bounds = mesh.calc_bounds();
                assert!(clipped.clip_rect.contains_rect(bounds));
                emoji.push((bounds, clipped.clip_rect, &image.pixels, mesh.texture_id));
            }
        }
        assert_eq!(
            emoji.len(),
            3,
            "two filename emoji and a single joined emoji in the path"
        );
        let (face, rose, coder) = (&emoji[0], &emoji[1], &emoji[2]);
        assert_eq!(face.1, rose.1);
        assert!(face.0.right() <= rose.0.left());
        assert!(rose.1.right() < coder.1.left());
        assert!(text_position(&output, ".txt").x > rose.0.right());
        assert!(face
            .2
            .iter()
            .any(|p| p.r() > 190 && p.g() > 130 && p.b() < 100));
        assert!(face.2.iter().any(|p| p.b() > 180 && p.r() < 140));
        assert!(rose.2.iter().any(|p| p.r() > 140 && p.g() < 100));
        assert!(rose
            .2
            .iter()
            .any(|p| p.g() > 75 && p.g() > p.r() && p.g() > p.b()));
        assert_eq!(app.results[0].name, name);
        assert_eq!(app.results[0].path, PathBuf::from("work👩🏽‍💻").join(name));

        let multiline = format!("{}\n😭🥀.log", "x".repeat(150));
        let result = entry(&multiline, 0);
        app.icons.insert(result.path.clone(), None);
        app.results[0] = result;
        let multiline_output = frame(&ctx, &mut app, vec![]);
        let suffix = text_position(&multiline_output, ".log");
        assert!(face.1.contains(suffix));
        for id in [face.3, rose.3] {
            assert!(multiline_output.shapes.iter().any(|shape| {
                matches!(&shape.shape, egui::Shape::Mesh(mesh)
                    if mesh.texture_id == id && shape.clip_rect.intersects(mesh.calc_bounds()))
            }));
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
        app.append_hits([(MatchKind::Exact, entry("rom.exe", 4))]);
        assert_eq!(app.results[0].name, "ROM.EXE");
        assert_eq!(app.results[1].name, "rom.exe");
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
    fn help_menu_opens_syntax_and_keeps_searching_while_blocking_result_actions() {
        let ctx = egui::Context::default();
        let mut app = App {
            query: "notes".into(),
            results: vec![entry("first", 1), entry("second", 2)],
            selected: Some(0),
            ..Default::default()
        };
        let render = |app: &mut App, events| {
            ctx.run(frame_input(events), |ctx| {
                // Exercise the in-window menu even on hosts that normally use a native menu.
                #[cfg(any(target_os = "macos", target_os = "windows"))]
                in_window_search_menu(ctx, app);
                app.update_ui_with_opener(ctx, &mut |_, _| panic!("help opened a result"));
            })
        };
        let click = |app: &mut App, pos| {
            for pressed in [true, false] {
                render(
                    app,
                    pointer_events(pos, egui::PointerButton::Primary, pressed),
                );
            }
            render(app, vec![])
        };
        let open_help = |app: &mut App| {
            let menu = text_position(&render(app, vec![]), "Help");
            click(app, menu);
            let item = text_position(&render(app, vec![]), "Syntax");
            click(app, item);
            let output = render(app, vec![]);
            text_position(&output, "Search syntax");
            text_position(&output, "fuzzy:projecx notes");
            assert!(app.syntax_open);
        };
        let row = text_position(&render(&mut app, vec![]), "second");
        open_help(&mut app);
        click(&mut app, row);
        click(&mut app, row);
        render(
            &mut app,
            vec![key(Key::ArrowDown), egui::Event::Text("extra".into())],
        );
        assert_eq!(app.selected, Some(0));
        assert_eq!(app.query, "notes");

        let folder = tempfile::tempdir().unwrap();
        std::fs::write(folder.path().join("notes.txt"), b"new hit").unwrap();
        app.search = Some(Results::Walk(Search::start(
            "notes".into(),
            vec![folder.path().to_owned()],
        )));
        let deadline = Instant::now() + Duration::from_secs(5);
        while !app.completed {
            render(&mut app, vec![]);
            assert!(
                Instant::now() < deadline,
                "search stalled while reading help"
            );
            std::thread::yield_now();
        }
        assert_eq!(app.results.len(), 3);
        assert!(app.syntax_open);
        let output = render(&mut app, vec![key(Key::Escape)]);
        assert!(!app.syntax_open);
        assert!(!output.viewport_output[&egui::ViewportId::ROOT]
            .commands
            .contains(&egui::ViewportCommand::Close));
        render(&mut app, vec![]);
        render(&mut app, vec![egui::Event::Text("!".into())]);
        assert_eq!(app.query, "notes!");

        for button in ["×", "Close"] {
            open_help(&mut app);
            let pos = text_position(&render(&mut app, vec![]), button);
            click(&mut app, pos);
            assert!(!app.syntax_open);
        }
        open_help(&mut app);
        render(&mut app, vec![key(Key::Enter)]);
        assert!(!app.syntax_open, "the Close button takes keyboard focus");
    }

    #[test]
    fn syntax_examples_scroll_in_a_small_window_with_close_always_visible() {
        let ctx = egui::Context::default();
        let screen = egui::Rect::from_min_size(egui::Pos2::ZERO, egui::vec2(320.0, 240.0));
        let render = |events| {
            let mut input = frame_input(events);
            input.screen_rect = Some(screen);
            ctx.run(input, |ctx| assert!(!syntax_help::show(ctx)))
        };
        render(vec![]);
        let opening = render(vec![]);
        let words = text_position(&opening, "Words");
        assert!(screen.contains(words));
        let close = text_position(&opening, "Close");
        assert!(screen.contains(close));
        render(vec![
            egui::Event::PointerMoved(words),
            egui::Event::MouseWheel {
                unit: egui::MouseWheelUnit::Point,
                delta: egui::vec2(0.0, -3000.0),
                modifiers: egui::Modifiers::NONE,
            },
        ]);
        for _ in 0..30 {
            render(vec![]);
        }
        let bottom = render(vec![]);
        assert!(screen.contains(text_position(&bottom, "More pattern syntax")));
        assert_eq!(text_position(&bottom, "Close"), close);
    }

    #[test]
    fn context_menu_copies_original_path_after_late_exact_hit() {
        let ctx = egui::Context::default();
        let mut app = App::default();
        let original = entry("rom.exe.bak", 1);
        let path = original.path.to_string_lossy().into_owned();
        app.append_hits([(MatchKind::Partial, original)]);
        let pos = text_position(&frame(&ctx, &mut app, vec![]), "rom.exe.bak");
        for pressed in [true, false] {
            let _ = frame(
                &ctx,
                &mut app,
                pointer_events(pos, egui::PointerButton::Secondary, pressed),
            );
        }
        app.append_hits([(MatchKind::Exact, entry("rom.exe", 2))]);
        let _ = frame(&ctx, &mut app, vec![]);
        let copy = text_position(&frame(&ctx, &mut app, vec![]), "Copy Full Path");
        let _ = frame(
            &ctx,
            &mut app,
            pointer_events(copy, egui::PointerButton::Primary, true),
        );
        let output = frame(
            &ctx,
            &mut app,
            pointer_events(copy, egui::PointerButton::Primary, false),
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
            ctx.run(frame_input(events), |ctx| {
                app.update_ui_with_opener(ctx, &mut |_, _| {
                    panic!("Enter on a menu or dialog launched the selected application")
                })
            })
        };
        let point = text_position(&render(&mut app, vec![]), "Example.exe");
        for pressed in [true, false] {
            render(
                &mut app,
                pointer_events(point, egui::PointerButton::Secondary, pressed),
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
                ctx.run(frame_input(events), |ctx| {
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
                        pointer_events(pos, egui::PointerButton::Primary, pressed),
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
                    pointer_events(pos, egui::PointerButton::Primary, pressed),
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
                    pointer_events(pos, egui::PointerButton::Primary, pressed),
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
        let name = path.file_name().unwrap().to_str().unwrap().to_owned();
        let mut result = entry(&name, 1);
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
                        egui::Shape::Text(text) if text.galley.text() == name => Some(text.pos),
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
        let file = exe_icon::temporary_pe32();
        assert_result_loads_embedded_icon(file.path().to_path_buf());
    }
    #[test]
    fn visible_appimage_rows_draw_their_embedded_png_and_svg() {
        let root = tempfile::tempdir().unwrap();
        let fixtures =
            Path::new(env!("CARGO_MANIFEST_DIR")).join("tools/appimage-icon-wasm/tests/fixtures");
        for (name, fixture) in [
            ("linked.aPpImAgE", "linked-png.AppImage"),
            ("legacy.AppImage", "rock-ridge.AppImage"),
            ("direct.AppImage", "direct-svg.AppImage"),
        ] {
            let path = root.path().join(name);
            std::fs::copy(fixtures.join(fixture), &path).unwrap();
            assert_result_loads_embedded_icon(path);
        }
    }

    #[test]
    fn appimage_checkbox_invalidates_cached_icon_and_reloads_when_enabled() {
        let ctx = egui::Context::default();
        let path = Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("tools/appimage-icon-wasm/tests/fixtures/linked-png.AppImage");
        let mut item = entry("linked-png.AppImage", 1);
        item.path = path.clone();
        let mut app = App {
            results: vec![item],
            interface_open: true,
            appimage_type_icon: Some(None), // exercise the generic fallback without a window server
            ..Default::default()
        };
        let render_until_loaded = |app: &mut App| {
            let deadline = Instant::now() + Duration::from_secs(10);
            while !matches!(app.icons.get(&path), Some(Some(_))) {
                frame(&ctx, app, vec![]);
                assert!(Instant::now() < deadline, "AppImage icon did not arrive");
                std::thread::sleep(Duration::from_millis(10));
            }
        };
        let toggle = |app: &mut App| {
            let point = text_position(
                &frame(&ctx, app, vec![]),
                "Use embedded icons for AppImages",
            );
            for pressed in [true, false] {
                frame(
                    &ctx,
                    app,
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
        };
        render_until_loaded(&mut app);
        let first = app.icons[&path].as_ref().unwrap().id();
        toggle(&mut app);
        assert!(!app.embedded_appimage_icons && app.embedded_exe_icons);
        assert!(matches!(app.icons.get(&path), Some(None)));
        assert!(app.pending_icons.is_empty());
        toggle(&mut app);
        render_until_loaded(&mut app);
        assert_ne!(first, app.icons[&path].as_ref().unwrap().id());
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
    fn invalid_pattern_shows_inline_feedback_and_can_be_edited() {
        let ctx = egui::Context::default();
        let mut app = App::default();
        let _ = frame(&ctx, &mut app, vec![]);
        app.results.push(entry("stale", 0));
        let _ = frame(&ctx, &mut app, vec![egui::Event::Text("regex:[".into())]);
        app.changed = Some(Instant::now() - Duration::from_millis(250));
        let output = frame(&ctx, &mut app, vec![]);
        let error = app.query_error.as_deref().expect("expected a syntax error");
        assert!(error.starts_with("Invalid regex"));
        text_position(&output, error);
        assert!(app.results.is_empty() && !app.can_stop());
        assert!(app.starting.is_none() && app.search.is_none());
        let _ = frame(&ctx, &mut app, vec![egui::Event::Text("abc]".into())]);
        assert_eq!(app.query, "regex:[abc]");
        assert!(app.query_error.is_none() && app.changed.is_some());
        assert!(SearchQuery::parse(&app.query).classify("a").is_some());
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
