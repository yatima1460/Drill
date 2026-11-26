use egui::{Event, PlatformOutput};
use egui_winit::{EventResponse, State};
use winit::{event::WindowEvent, window::Window};

#[cfg(any(target_os = "macos", all(windows, feature = "drill-windows-clipboard")))]
use {
    egui::{ColorImage, Key, Modifiers, OutputCommand},
    winit::{
        event::ElementState,
        keyboard::{Key as WinitKey, KeyCode, NamedKey, PhysicalKey},
    },
};

#[cfg(target_os = "macos")]
pub(crate) mod macos;

#[cfg(all(windows, feature = "drill-windows-clipboard"))]
pub(crate) mod windows;

pub(super) fn handle_platform_output(state: &mut State, window: &Window, output: PlatformOutput) {
    #[cfg(target_os = "macos")]
    let output = macos::copy_to_pasteboard(output);
    #[cfg(all(windows, feature = "drill-windows-clipboard"))]
    let output = windows::copy_to_clipboard(window, output);
    state.handle_platform_output(window, output);
}

pub(super) fn request_paste(state: &mut State) {
    #[cfg(target_os = "macos")]
    let text = macos::clipboard_text(state);
    #[cfg(all(windows, feature = "drill-windows-clipboard"))]
    let text = windows::read_text();
    #[cfg(not(any(target_os = "macos", all(windows, feature = "drill-windows-clipboard"))))]
    let text = state.clipboard_text();

    state.egui_input_mut().events.extend(paste_event(text));
}

fn paste_event(text: Option<String>) -> Option<Event> {
    let text = text?.replace("\r\n", "\n");
    (!text.is_empty()).then_some(Event::Paste(text))
}

#[cfg(any(target_os = "macos", all(windows, feature = "drill-windows-clipboard")))]
fn straight_rgba(image: &ColorImage) -> Option<Vec<u8>> {
    let [width, height] = image.size;
    if width == 0 || height == 0 || width.checked_mul(height) != Some(image.pixels.len()) {
        return None;
    }
    Some(
        image
            .pixels
            .iter()
            .flat_map(egui::Color32::to_srgba_unmultiplied)
            .collect(),
    )
}

#[allow(deprecated)] // Preserve the order of the deprecated copied_text field.
#[cfg(any(target_os = "macos", all(windows, feature = "drill-windows-clipboard")))]
fn write_clipboard_commands(
    output: &mut PlatformOutput,
    keep_fallback_text: bool,
    mut write_text: impl FnMut(&str),
    mut write_image: impl FnMut(&ColorImage),
) {
    output.commands.retain(|command| match command {
        OutputCommand::CopyText(text) => {
            write_text(text);
            keep_fallback_text
        }
        OutputCommand::CopyImage(image) => {
            write_image(image);
            false
        }
        _ => true,
    });
    if !output.copied_text.is_empty() {
        write_text(&output.copied_text);
        if !keep_fallback_text {
            output.copied_text.clear();
        }
    }
}

pub(super) fn on_window_event(
    state: &mut State,
    window: &Window,
    event: &WindowEvent,
) -> EventResponse {
    #[cfg(any(target_os = "macos", all(windows, feature = "drill-windows-clipboard")))]
    {
        native_window_event(state, window, event)
    }
    #[cfg(not(any(target_os = "macos", all(windows, feature = "drill-windows-clipboard"))))]
    {
        state.on_window_event(window, event)
    }
}

#[cfg(any(target_os = "macos", all(windows, feature = "drill-windows-clipboard")))]
fn native_window_event(state: &mut State, window: &Window, event: &WindowEvent) -> EventResponse {
    let input = state.egui_input();
    let first_new_event = input.events.len();
    let possible_paste = matches!(
        event,
        WindowEvent::KeyboardInput { event, is_synthetic: false, .. }
            if event.state == ElementState::Pressed
                && possible_paste_key(input.modifiers, &event.logical_key, event.physical_key)
    );
    let response = state.on_window_event(window, event);
    if possible_paste {
        #[cfg(target_os = "macos")]
        let read_text = macos::read_text;
        #[cfg(all(windows, feature = "drill-windows-clipboard"))]
        let read_text = || Some(windows::read_text());
        replace_keyboard_paste(
            &mut state.egui_input_mut().events,
            first_new_event,
            read_text,
        );
    }
    response
}

#[cfg(any(target_os = "macos", all(windows, feature = "drill-windows-clipboard")))]
fn possible_paste_key(modifiers: Modifiers, logical: &WinitKey, physical: PhysicalKey) -> bool {
    let logical = match logical {
        WinitKey::Named(NamedKey::Paste) => Some(Key::Paste),
        WinitKey::Named(NamedKey::Insert) => Some(Key::Insert),
        WinitKey::Character(name) => Key::from_name(name.as_str()),
        _ => None,
    };
    let key = logical.or(match physical {
        PhysicalKey::Code(KeyCode::Paste) => Some(Key::Paste),
        PhysicalKey::Code(KeyCode::Insert) => Some(Key::Insert),
        PhysicalKey::Code(KeyCode::KeyV) => Some(Key::V),
        _ => None,
    });
    key == Some(Key::Paste)
        || (modifiers.command && key == Some(Key::V))
        || (cfg!(windows) && modifiers.shift && key == Some(Key::Insert))
}

#[cfg(any(target_os = "macos", all(windows, feature = "drill-windows-clipboard")))]
fn replace_keyboard_paste(
    events: &mut Vec<Event>,
    first_new_event: usize,
    read_text: impl FnOnce() -> Option<Option<String>>,
) {
    // egui-winit consumes paste shortcuts even when its in-process clipboard is empty.
    // Other emitted events mean egui-winit recognized a different key or command.
    if !matches!(&events[first_new_event..], [] | [Event::Paste(_)]) {
        return;
    }
    if let Some(text) = read_text() {
        events.truncate(first_new_event);
        events.extend(paste_event(text));
    }
}
