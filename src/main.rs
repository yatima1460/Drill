#![cfg_attr(target_os = "windows", windows_subsystem = "windows")]
use chrono::{DateTime, Local};
use drill::search::{default_roots, Entry, Search};
use eframe::egui::{self, Key, RichText};
use std::path::Path;
use std::time::{Duration, Instant};

const LIMIT: usize = 10_000;
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
impl eframe::App for App {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
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
            self.selected = None;
            self.limited = false;
            if !self.query.trim().is_empty() {
                let query = self.query.clone();
                let (tx, rx) = std::sync::mpsc::sync_channel(1);
                self.starting = Some(rx);
                std::thread::spawn(move || {
                    let _ = tx.send(Search::start(query, default_roots()));
                });
            }
        }
        if let Some(starting) = &self.starting {
            if let Ok(search) = starting.try_recv() {
                self.search = Some(search);
                self.starting = None;
            }
        }
        if let Some(search) = &self.search {
            for _ in 0..500 {
                match search.try_recv() {
                    Ok(entry) => {
                        self.results.push(entry);
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
                self.selected = None;
                self.limited = false;
                self.changed = if self.query.trim().is_empty() {
                    None
                } else {
                    Some(Instant::now())
                };
            }
            if ctx.input(|i| i.key_pressed(Key::ArrowDown)) && !self.results.is_empty() {
                self.selected = Some(
                    self.selected
                        .map_or(0, |n| (n + 1).min(self.results.len() - 1)),
                );
                response.surrender_focus();
            }
            if ctx.input(|i| i.key_pressed(Key::ArrowUp)) {
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
                for (name, fraction) in ["Name", "Path", "Size", "Date"].into_iter().zip(widths) {
                    ui.add_sized(
                        [total * fraction - 8.0, 20.0],
                        egui::Label::new(RichText::new(name).strong()),
                    );
                }
            });
            ui.separator();
            egui::ScrollArea::both()
                .auto_shrink([false, false])
                .show_rows(ui, 25.0, self.results.len(), |ui, range| {
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
                        let mut x = rect.left();
                        for (value, fraction) in values.into_iter().zip(widths) {
                            let column_width = total * fraction;
                            let clip = egui::Rect::from_min_max(
                                egui::pos2(x, rect.top()),
                                egui::pos2(x + column_width - 4.0, rect.bottom()),
                            );
                            ui.painter().with_clip_rect(clip).text(
                                egui::pos2(x + 4.0, rect.center().y),
                                egui::Align2::LEFT_CENTER,
                                value,
                                egui::TextStyle::Body.resolve(ui.style()),
                                ui.visuals().text_color(),
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
        });
        if (self.search.is_some() && !self.completed)
            || self.starting.is_some()
            || self.changed.is_some()
        {
            ctx.request_repaint_after(Duration::from_millis(30));
        }
    }
}
fn main() -> eframe::Result {
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
    eframe::run_native("Drill", options, Box::new(|_| Ok(Box::<App>::default())))
}
