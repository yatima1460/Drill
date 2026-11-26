use std::sync::{Arc, Mutex};

use muda::{Menu, MenuEvent, MenuItem, Submenu};
use raw_window_handle::{HasWindowHandle, RawWindowHandle};

use super::{Command, MenuState, Requests};

pub struct NativeMenu {
    _menu: Menu,
    stop: MenuItem,
    settings: Submenu,
    requests: Arc<Mutex<MenuState>>,
}

impl NativeMenu {
    #[allow(unsafe_code)]
    pub fn new(creation: &eframe::CreationContext<'_>) -> Result<Self, String> {
        let stop = MenuItem::new("Stop", false, None);
        let search = Submenu::with_items("Search", true, &[&stop]).map_err(|e| e.to_string())?;
        let interface = MenuItem::new("Interface…", true, None);
        let syntax = MenuItem::new("Syntax", true, None);
        let help = Submenu::with_items("Help", true, &[&syntax]).map_err(|e| e.to_string())?;
        let settings =
            Submenu::with_items("Settings", true, &[&interface]).map_err(|e| e.to_string())?;
        let menu = Menu::new();
        menu.append(&search).map_err(|e| e.to_string())?;
        menu.append(&settings).map_err(|e| e.to_string())?;
        menu.append(&help).map_err(|e| e.to_string())?;
        let handle = creation.window_handle().map_err(|e| e.to_string())?;
        let RawWindowHandle::Win32(handle) = handle.as_raw() else {
            return Err("Expected a Windows window".into());
        };
        // SAFETY: eframe owns this live window for the lifetime of the menu.
        unsafe { menu.init_for_hwnd(handle.hwnd.get()) }.map_err(|e| e.to_string())?;
        let requests = Arc::new(Mutex::new(MenuState::default()));
        let target = Arc::clone(&requests);
        let commands = [
            (stop.id().clone(), Command::Stop),
            (interface.id().clone(), Command::Interface),
            (syntax.id().clone(), Command::Syntax),
        ];
        let context = creation.egui_ctx.clone();
        MenuEvent::set_event_handler(Some(move |event: MenuEvent| {
            if let Some((_, command)) = commands.iter().find(|(id, _)| *id == event.id) {
                if target.lock().unwrap().request(*command) {
                    context.request_repaint();
                }
            }
        }));
        Ok(Self {
            _menu: menu,
            stop,
            settings,
            requests,
        })
    }
    pub fn set_enabled(&self, can_stop: bool) {
        let background_enabled = !self.requests.lock().unwrap().reading_syntax;
        let stop_enabled = can_stop && background_enabled;
        if self.stop.is_enabled() != stop_enabled {
            self.stop.set_enabled(stop_enabled);
        }
        if self.settings.is_enabled() != background_enabled {
            self.settings.set_enabled(background_enabled);
        }
    }
    pub fn take_requests(&self) -> Requests {
        self.requests.lock().unwrap().take_requests()
    }
    pub fn syntax_closed(&self) {
        self.requests.lock().unwrap().syntax_closed();
    }
}
