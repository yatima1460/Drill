use drill_gtk::desktop_theme::Observer;
use eframe::egui::{Context, Theme};
use std::sync::{Arc, Mutex};

pub(crate) struct DesktopTheme {
    value: Arc<Mutex<Option<Theme>>>,
    _observer: Observer,
}

impl DesktopTheme {
    pub(crate) fn new(ctx: Context) -> Self {
        let value = Arc::new(Mutex::new(None));
        let cache = Arc::clone(&value);
        let observer = Observer::start(move |dark| {
            let theme = dark.map(Theme::from_dark_mode);
            let mut previous = cache.lock().unwrap();
            if *previous != theme {
                *previous = theme;
                drop(previous);
                ctx.request_repaint();
            }
        });
        Self {
            value,
            _observer: observer,
        }
    }

    pub(crate) fn current(&self) -> Option<Theme> {
        *self.value.lock().unwrap()
    }
}
