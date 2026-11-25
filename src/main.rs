#![cfg_attr(target_os = "windows", windows_subsystem = "windows")]
#![deny(unsafe_code)]
use chrono::{DateTime, Local};
use drill_core::{default_roots, Entry, Search};
use eframe::egui::{self, Key, RichText};
use std::path::Path;
use std::time::{Duration, Instant};

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
    completed: bool,
    results: Vec<Entry>,
    selected: Option<usize>,
    limited: bool,
    focus_search: bool,
    scroll_offset: f32,
    icons: std::collections::HashMap<std::path::PathBuf, Option<egui::TextureHandle>>,
    sort: Option<(SortColumn, bool)>,
}
impl Default for App {
    fn default() -> Self {
        Self {
            query: String::new(),
            changed: None,
            search: None,
            starting: None,
            completed: false,
            results: Vec::new(),
            selected: None,
            limited: false,
            focus_search: true,
            scroll_offset: 0.0,
            icons: std::collections::HashMap::new(),
            sort: None,
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
impl App {
    fn update_ui(&mut self, ctx: &egui::Context) {
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
            self.starting = None;
            self.completed = false;
            self.results.clear();
            self.icons.clear();
            self.selected = None;
            self.limited = false;
            if !self.query.trim().is_empty() {
                let query = self.query.clone();
                let (tx, rx) = std::sync::mpsc::sync_channel(1);
                self.starting = Some(rx);
                std::thread::spawn(move || {
                    #[cfg(feature = "ui-test-driver")]
                    let roots = std::env::var_os("DRILL_UI_TEST_ROOT")
                        .map(|p| vec![p.into()])
                        .unwrap_or_else(default_roots);
                    #[cfg(not(feature = "ui-test-driver"))]
                    let roots = default_roots();
                    let _ = tx.send(Search::start(query, roots));
                });
            }
        }
        if let Some(starting) = &self.starting {
            if let Ok(search) = starting.try_recv() {
                self.search = Some(search);
                self.starting = None;
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
        let title = if self.limited {
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
        let mut icon_budget = 4;
        let mut icons_pending = false;
        egui::CentralPanel::default().show(ctx, |ui| {
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
                self.starting = None;
                self.completed = false;
                self.results.clear();
                self.icons.clear();
                self.selected = None;
                self.limited = false;
                self.changed = if self.query.trim().is_empty() {
                    None
                } else {
                    Some(Instant::now())
                };
            }
            let mut keyboard_selection_changed = false;
            if ctx.input(|i| i.key_pressed(Key::ArrowDown)) && !self.results.is_empty() {
                keyboard_selection_changed = true;
                self.selected = Some(
                    self.selected
                        .map_or(0, |n| (n + 1).min(self.results.len() - 1)),
                );
                response.surrender_focus();
            }
            if ctx.input(|i| i.key_pressed(Key::ArrowUp)) {
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
            if ctx.input(|i| i.key_pressed(Key::Enter)) {
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
                    let suffix = match self.sort {
                        Some((current, ascending)) if current == column => {
                            if ascending {
                                " ▲"
                            } else {
                                " ▼"
                            }
                        }
                        _ => "",
                    };
                    let label = egui::Label::new(RichText::new(format!("{name}{suffix}")).strong())
                        .sense(egui::Sense::click());
                    if ui
                        .add_sized([total * fraction - 8.0, 20.0], label)
                        .clicked()
                    {
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
                    self.selected = selected_path
                        .and_then(|path| self.results.iter().position(|entry| entry.path == path));
                }
            }
            ui.separator();
            let mut area = egui::ScrollArea::both().auto_shrink([false, false]);
            if keyboard_selection_changed {
                if let Some(selected) = self.selected {
                    let height = ui.available_height();
                    let top = selected as f32 * 25.0;
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
                            egui::pos2(x + if column == 0 { 24.0 } else { 4.0 }, rect.center().y),
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
                        if ui.button("Reveal in file manager").clicked() {
                            open(&entry.path, true);
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

#[cfg(target_os = "macos")]
#[allow(unsafe_code)]
fn set_dock_icon() {
    use objc2::{AnyThread, MainThreadMarker};
    use objc2_app_kit::{NSApplication, NSImage};
    use objc2_foundation::NSData;
    let marker = MainThreadMarker::new().expect("desktop application runs on the main thread");
    let data = NSData::with_bytes(include_bytes!("assets/drill.png"));
    if let Some(image) = NSImage::initWithData(NSImage::alloc(), &data) {
        // SAFETY: the marker establishes the main thread, and Some(&image) supplies a live, non-null NSImage.
        unsafe {
            NSApplication::sharedApplication(marker).setApplicationIconImage(Some(&image));
        }
    }
}
fn main() -> eframe::Result {
    if std::env::args().any(|arg| arg == "--version") {
        println!("Drill {}", env!("CARGO_PKG_VERSION"));
        return Ok(());
    }
    let icon = image::load_from_memory(include_bytes!("assets/drill.png"))
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
            #[cfg(target_os = "macos")]
            set_dock_icon();
            Ok(Box::<App>::default())
        }),
    )
}

#[cfg(test)]
mod ui_tests {
    use super::*;
    use std::path::PathBuf;

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
        assert!(app.scroll_offset > 0.0);
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
        let point = egui::pos2(20.0, 66.0);
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
