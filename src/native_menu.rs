use muda::{Menu, MenuEvent, MenuItem, Submenu};
use std::sync::{
    atomic::{AtomicBool, Ordering},
    Arc,
};

pub struct NativeMenu {
    _menu: Menu,
    stop: MenuItem,
    requested: Arc<AtomicBool>,
    interface_requested: Arc<AtomicBool>,
    syntax_requested: Arc<AtomicBool>,
    #[cfg(target_os = "macos")]
    permissions_requested: Arc<AtomicBool>,
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
        let requested = Arc::new(AtomicBool::new(false));
        let target = requested.clone();
        let id = stop.id().clone();
        let interface_requested = Arc::new(AtomicBool::new(false));
        let interface_target = interface_requested.clone();
        let interface_id = interface.id().clone();
        let syntax_requested = Arc::new(AtomicBool::new(false));
        let syntax_target = syntax_requested.clone();
        let syntax_id = syntax.id().clone();
        #[cfg(target_os = "macos")]
        let permissions_requested = Arc::new(AtomicBool::new(false));
        #[cfg(target_os = "macos")]
        let permissions_target = permissions_requested.clone();
        #[cfg(target_os = "macos")]
        let permissions_id = permissions.id().clone();
        let context = creation.egui_ctx.clone();
        MenuEvent::set_event_handler(Some(move |event: MenuEvent| {
            if event.id == id {
                target.store(true, Ordering::Relaxed);
                context.request_repaint();
            }
            if event.id == interface_id {
                interface_target.store(true, Ordering::Relaxed);
                context.request_repaint();
            }
            if event.id == syntax_id {
                syntax_target.store(true, Ordering::Relaxed);
                context.request_repaint();
            }
            #[cfg(target_os = "macos")]
            if event.id == permissions_id {
                permissions_target.store(true, Ordering::Relaxed);
                context.request_repaint();
            }
        }));
        Ok(Self {
            _menu: menu,
            stop,
            requested,
            interface_requested,
            syntax_requested,
            #[cfg(target_os = "macos")]
            permissions_requested,
        })
    }
    pub fn set_enabled(&self, enabled: bool) {
        if self.stop.is_enabled() != enabled {
            self.stop.set_enabled(enabled);
        }
    }
    pub fn take_stop(&self) -> bool {
        self.requested.swap(false, Ordering::Relaxed)
    }
    pub fn take_interface(&self) -> bool {
        self.interface_requested.swap(false, Ordering::Relaxed)
    }
    pub fn take_syntax(&self) -> bool {
        self.syntax_requested.swap(false, Ordering::Relaxed)
    }
    #[cfg(target_os = "macos")]
    pub fn take_permissions(&self) -> bool {
        self.permissions_requested.swap(false, Ordering::Relaxed)
    }
}
