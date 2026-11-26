use drill_macos::clipboard::Pasteboard;
use egui::{ColorImage, Event, Key, Modifiers, OutputCommand, PlatformOutput};
use egui_winit::{EventResponse, State};
use winit::{
    event::{ElementState, WindowEvent},
    keyboard::{Key as WinitKey, KeyCode, NamedKey, PhysicalKey},
    window::Window,
};

fn write_text(pasteboard: &Pasteboard, text: &str) {
    if !pasteboard.set_text(text) {
        log::error!("Could not copy text to the macOS pasteboard");
    }
}

fn write_image(pasteboard: &Pasteboard, image: &ColorImage) -> bool {
    let [width, height] = image.size;
    if width == 0 || height == 0 || width.checked_mul(height) != Some(image.pixels.len()) {
        return false;
    }
    let pixels: Vec<u8> = image
        .pixels
        .iter()
        .flat_map(egui::Color32::to_srgba_unmultiplied)
        .collect();
    pasteboard.set_rgba(width, height, &pixels)
}

pub(super) fn clipboard_text(state: &mut State) -> Option<String> {
    match Pasteboard::general() {
        Some(pasteboard) => pasteboard.text(),
        None => state.clipboard_text(),
    }
}

#[allow(deprecated)] // Keep forwarding the legacy copied_text field to egui-winit.
pub(super) fn copy_to_pasteboard(mut output: PlatformOutput) -> PlatformOutput {
    if output.copied_text.is_empty()
        && !output.commands.iter().any(|command| {
            matches!(
                command,
                OutputCommand::CopyText(_) | OutputCommand::CopyImage(_)
            )
        })
    {
        return output;
    }
    let Some(pasteboard) = Pasteboard::general() else {
        return output;
    };
    write_clipboard_commands(&pasteboard, &mut output);
    output
}

#[allow(deprecated)] // Preserve the order of the deprecated copied_text field.
fn write_clipboard_commands(pasteboard: &Pasteboard, output: &mut PlatformOutput) {
    output.commands.retain(|command| match command {
        OutputCommand::CopyText(text) => {
            write_text(pasteboard, text);
            true
        }
        OutputCommand::CopyImage(image) => {
            if !write_image(pasteboard, image) {
                log::error!("Could not copy image to the macOS pasteboard");
            }
            false
        }
        _ => true,
    });
    if !output.copied_text.is_empty() {
        write_text(pasteboard, &output.copied_text);
    }
}

fn possible_paste_key(modifiers: Modifiers, logical: &WinitKey, physical: PhysicalKey) -> bool {
    let logical = match logical {
        WinitKey::Named(NamedKey::Paste) => Some(Key::Paste),
        WinitKey::Character(name) => Key::from_name(name.as_str()),
        _ => None,
    };
    logical == Some(Key::Paste)
        || (modifiers.command
            && logical.map_or(physical == PhysicalKey::Code(KeyCode::KeyV), |key| {
                key == Key::V
            }))
}

pub(in crate::native) fn on_window_event(
    state: &mut State,
    window: &Window,
    event: &WindowEvent,
) -> EventResponse {
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
        replace_keyboard_paste(&mut state.egui_input_mut().events, first_new_event, || {
            Some(Pasteboard::general()?.text())
        });
    }
    response
}

fn replace_keyboard_paste(
    events: &mut Vec<Event>,
    first_new_event: usize,
    read_text: impl FnOnce() -> Option<Option<String>>,
) {
    // egui-winit emits one Paste event for its in-process clipboard, or consumes
    // the same shortcut with no event if that clipboard is empty. A Key event
    // means the logical key took precedence over the physical shortcut candidate.
    if !matches!(&events[first_new_event..], [] | [Event::Paste(_)]) {
        return;
    }
    // An unavailable pasteboard leaves the framework fallback in place.
    if let Some(text) = read_text() {
        events.truncate(first_new_event);
        events.extend(super::paste_event(text));
    }
}

#[cfg(any(test, feature = "drill-clipboard-tests"))]
pub mod tests {
    //! Fixtures also run by Drill's workspace test suite.

    use super::*;

    /// Check the logical, physical and modifier key rules used by native paste.
    #[cfg_attr(test, test)]
    pub fn macos_paste_shortcuts_follow_egui_precedence() {
        let command = Modifiers::MAC_CMD | Modifiers::COMMAND;
        let physical_v = PhysicalKey::Code(KeyCode::KeyV);
        let physical_insert = PhysicalKey::Code(KeyCode::Insert);
        let key = |text: &str| WinitKey::Character(text.into());
        assert!(possible_paste_key(command, &key("v"), physical_insert));
        assert!(possible_paste_key(command, &key("м"), physical_v));
        assert!(!possible_paste_key(command, &key("k"), physical_v));
        assert!(!possible_paste_key(Modifiers::CTRL, &key("v"), physical_v));
        assert!(!possible_paste_key(
            Modifiers::SHIFT,
            &WinitKey::Named(NamedKey::Insert),
            physical_insert
        ));
        assert!(possible_paste_key(
            Modifiers::NONE,
            &WinitKey::Named(NamedKey::Paste),
            physical_insert
        ));
    }

    /// Check how native clipboard text replaces the framework fallback event.
    #[cfg_attr(test, test)]
    pub fn native_paste_replaces_the_framework_fallback_once() {
        let mut events = vec![Event::Copy, Event::Paste("stale".to_owned())];
        replace_keyboard_paste(&mut events, 1, || None);
        assert!(matches!(&events[1], Event::Paste(text) if text == "stale"));
        replace_keyboard_paste(&mut events, 1, || {
            Some(Some("žlutý 🌳\r\nsecond line".to_owned()))
        });
        assert!(matches!(
            &events[..],
            [Event::Copy, Event::Paste(text)] if text == "žlutý 🌳\nsecond line"
        ));

        let mut events = vec![Event::Cut];
        replace_keyboard_paste(&mut events, 0, || panic!("unexpected pasteboard read"));
        let mut events = Vec::new();
        replace_keyboard_paste(&mut events, 0, || Some(Some("native text".to_owned())));
        assert!(matches!(&events[..], [Event::Paste(_)]));

        replace_keyboard_paste(&mut events, 0, || Some(Some(String::new())));
        assert!(events.is_empty());
        replace_keyboard_paste(&mut events, 0, || Some(None));
        assert!(events.is_empty());
    }
}
