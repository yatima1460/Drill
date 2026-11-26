#[cfg(target_os = "macos")]
mod macos;
#[cfg(target_os = "windows")]
mod windows;

#[cfg(target_os = "macos")]
use macos as platform;
#[cfg(target_os = "windows")]
use windows as platform;

use std::{cell::RefCell, rc::Rc};

pub struct NativeMenu {
    menu: platform::Menu,
    state: Rc<RefCell<MenuState>>,
}

impl NativeMenu {
    pub fn new(creation: &eframe::CreationContext<'_>) -> Result<Self, String> {
        let state = Rc::new(RefCell::new(MenuState::default()));
        let target = Rc::clone(&state);
        let context = creation.egui_ctx.clone();
        let menu = platform::install(creation, move |action| {
            let command = match action {
                platform::NativeCommand::Stop => Command::Stop,
                platform::NativeCommand::Interface => Command::Interface,
                platform::NativeCommand::Syntax => Command::Syntax,
                #[cfg(target_os = "macos")]
                platform::NativeCommand::Permissions => Command::Permissions,
            };
            if target.borrow_mut().request(command) {
                context.request_repaint();
            }
        })?;
        Ok(Self { menu, state })
    }

    pub fn set_enabled(&self, can_stop: bool) {
        let settings = !self.state.borrow().reading_syntax;
        self.menu.set_enabled(can_stop && settings, settings);
    }

    #[cfg(windows)]
    pub fn set_dark(&self, dark: bool) {
        self.menu.set_dark(dark);
    }

    pub fn take_requests(&self) -> Requests {
        self.state.borrow_mut().take_requests()
    }

    pub fn syntax_closed(&self) {
        self.state.borrow_mut().syntax_closed();
    }
}

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
