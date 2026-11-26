use muda::{Menu, MenuEvent, MenuItem, Submenu};
use std::sync::{Arc, Mutex};

#[derive(Default)]
pub(super) struct Requests {
    pub(super) stop: bool,
    pub(super) interface: bool,
    pub(super) syntax: bool,
    #[cfg(target_os = "macos")]
    pub(super) permissions: bool,
}

#[derive(Default)]
struct MenuState {
    pending: Requests,
    reading_syntax: bool,
}

#[derive(Clone, Copy)]
enum Command {
    Stop,
    Interface,
    Syntax,
    #[cfg(target_os = "macos")]
    Permissions,
}

impl MenuState {
    fn request(&mut self, command: Command) -> bool {
        if self.reading_syntax {
            return false;
        }
        match command {
            Command::Syntax => {
                // The native callback can run before egui gets a frame to disable the menus.
                self.reading_syntax = true;
                self.pending = Requests {
                    syntax: true,
                    ..Requests::default()
                };
            }
            Command::Stop => self.pending.stop = true,
            Command::Interface => self.pending.interface = true,
            #[cfg(target_os = "macos")]
            Command::Permissions => self.pending.permissions = true,
        }
        true
    }

    fn take_requests(&mut self) -> Requests {
        std::mem::take(&mut self.pending)
    }

    fn syntax_closed(&mut self) {
        self.reading_syntax = false;
    }
}

pub struct NativeMenu {
    _menu: Menu,
    stop: MenuItem,
    settings: Submenu,
    requests: Arc<Mutex<MenuState>>,
}

impl NativeMenu {
    #[cfg_attr(target_os = "windows", allow(unsafe_code))]
    pub fn new(creation: &eframe::CreationContext<'_>) -> Result<Self, String> {
        let stop = MenuItem::new("Stop", false, None);
        let search = Submenu::with_items("Search", true, &[&stop]).map_err(|e| e.to_string())?;
        #[cfg(target_os = "macos")]
        let permissions = MenuItem::new("Permissions…", true, None);
        let interface = MenuItem::new("Interface…", true, None);
        let syntax = MenuItem::new("Syntax", true, None);
        let help = Submenu::with_items("Help", true, &[&syntax]).map_err(|e| e.to_string())?;
        #[cfg(target_os = "macos")]
        let settings = Submenu::with_items("Settings", true, &[&interface, &permissions])
            .map_err(|e| e.to_string())?;
        #[cfg(target_os = "windows")]
        let settings =
            Submenu::with_items("Settings", true, &[&interface]).map_err(|e| e.to_string())?;
        let menu = Menu::new();
        #[cfg(target_os = "macos")]
        {
            use muda::PredefinedMenuItem as Item;
            let app = Submenu::with_items(
                "Drill",
                true,
                &[
                    &Item::about(None, None),
                    &Item::separator(),
                    &Item::services(None),
                    &Item::separator(),
                    &Item::hide(None),
                    &Item::hide_others(None),
                    &Item::show_all(None),
                    &Item::separator(),
                    &Item::quit(None),
                ],
            )
            .map_err(|e| e.to_string())?;
            menu.append(&app).map_err(|e| e.to_string())?;
        }
        menu.append(&search).map_err(|e| e.to_string())?;
        menu.append(&settings).map_err(|e| e.to_string())?;
        menu.append(&help).map_err(|e| e.to_string())?;
        #[cfg(target_os = "macos")]
        {
            menu.init_for_nsapp();
            help.set_as_help_menu_for_nsapp();
        }
        #[cfg(target_os = "windows")]
        {
            use raw_window_handle::{HasWindowHandle, RawWindowHandle};
            let handle = creation.window_handle().map_err(|e| e.to_string())?;
            let RawWindowHandle::Win32(handle) = handle.as_raw() else {
                return Err("Expected a Windows window".into());
            };
            // SAFETY: eframe owns this live window for the lifetime of the menu.
            unsafe { menu.init_for_hwnd(handle.hwnd.get()) }.map_err(|e| e.to_string())?;
        }
        let requests = Arc::new(Mutex::new(MenuState::default()));
        let target = Arc::clone(&requests);
        let commands = [
            (stop.id().clone(), Command::Stop),
            (interface.id().clone(), Command::Interface),
            (syntax.id().clone(), Command::Syntax),
            #[cfg(target_os = "macos")]
            (permissions.id().clone(), Command::Permissions),
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn syntax_discards_competing_native_commands_until_dismissed() {
        let mut state = MenuState::default();
        let background = [
            Command::Stop,
            Command::Interface,
            #[cfg(target_os = "macos")]
            Command::Permissions,
        ];
        for command in background {
            assert!(state.request(command));
        }
        assert!(state.request(Command::Syntax));
        let opened = state.take_requests();
        assert!(opened.syntax && !opened.stop && !opened.interface);
        #[cfg(target_os = "macos")]
        assert!(!opened.permissions);
        for command in background {
            assert!(!state.request(command));
        }
        assert!(!state.request(Command::Syntax));
        state.syntax_closed();
        let dismissed = state.take_requests();
        assert!(!dismissed.stop && !dismissed.interface && !dismissed.syntax);
        #[cfg(target_os = "macos")]
        assert!(!dismissed.permissions);
        assert!(state.request(Command::Stop) && state.take_requests().stop);
    }
}
