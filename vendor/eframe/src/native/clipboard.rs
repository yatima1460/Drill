use egui::{Event, PlatformOutput};
use egui_winit::State;
use winit::window::Window;

#[cfg(target_os = "macos")]
mod macos;

#[cfg(target_os = "macos")]
pub(super) use macos::on_window_event;

pub(super) fn handle_platform_output(state: &mut State, window: &Window, output: PlatformOutput) {
    #[cfg(target_os = "macos")]
    let output = macos::copy_to_pasteboard(output);
    state.handle_platform_output(window, output);
}

pub(super) fn request_paste(state: &mut State) {
    #[cfg(target_os = "macos")]
    let text = macos::clipboard_text(state);
    #[cfg(not(target_os = "macos"))]
    let text = state.clipboard_text();

    state.egui_input_mut().events.extend(paste_event(text));
}

fn paste_event(text: Option<String>) -> Option<Event> {
    let text = text?.replace("\r\n", "\n");
    (!text.is_empty()).then_some(Event::Paste(text))
}
