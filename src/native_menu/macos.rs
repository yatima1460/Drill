use std::{cell::RefCell, rc::Rc};

use drill_macos::menu::{Command as MacCommand, Menu};

use super::{Command, MenuState, Requests};

pub struct NativeMenu {
    menu: Menu,
    state: Rc<RefCell<MenuState>>,
}

impl NativeMenu {
    pub fn new(creation: &eframe::CreationContext<'_>) -> Result<Self, String> {
        let state = Rc::new(RefCell::new(MenuState::default()));
        let callback_state = Rc::clone(&state);
        let context = creation.egui_ctx.clone();
        let menu = Menu::install(move |command| {
            let command = match command {
                MacCommand::Stop => Command::Stop,
                MacCommand::Interface => Command::Interface,
                MacCommand::Syntax => Command::Syntax,
                MacCommand::Permissions => Command::Permissions,
            };
            if callback_state.borrow_mut().request(command) {
                context.request_repaint();
            }
        })
        .ok_or("The macOS application menu is unavailable")?;
        Ok(Self { menu, state })
    }

    pub fn set_enabled(&self, can_stop: bool) {
        let settings = !self.state.borrow().reading_syntax;
        self.menu.set_enabled(can_stop && settings, settings);
    }

    pub fn take_requests(&self) -> Requests {
        self.state.borrow_mut().take_requests()
    }

    pub fn syntax_closed(&self) {
        self.state.borrow_mut().syntax_closed();
    }
}
