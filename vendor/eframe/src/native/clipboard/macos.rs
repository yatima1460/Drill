use drill_macos::clipboard::Pasteboard;
use egui::{ColorImage, OutputCommand, PlatformOutput};
use egui_winit::State;

fn write_text(pasteboard: &Pasteboard, text: &str) {
    if !pasteboard.set_text(text) {
        log::error!("Could not copy text to the macOS pasteboard");
    }
}

fn write_image(pasteboard: &Pasteboard, image: &ColorImage) {
    let [width, height] = image.size;
    let copied = super::straight_rgba(image)
        .is_some_and(|pixels| pasteboard.set_rgba(width, height, &pixels));
    if !copied {
        log::error!("Could not copy image to the macOS pasteboard");
    }
}

pub(super) fn clipboard_text(state: &mut State) -> Option<String> {
    match read_text() {
        Some(text) => text,
        None => state.clipboard_text(),
    }
}

pub(super) fn read_text() -> Option<Option<String>> {
    Some(Pasteboard::general()?.text())
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
    super::write_clipboard_commands(
        &mut output,
        true,
        |text| write_text(&pasteboard, text),
        |image| write_image(&pasteboard, image),
    );
    output
}

#[cfg(any(test, feature = "drill-clipboard-tests"))]
pub mod tests {
    //! Fixtures also run by Drill's workspace test suite.

    use super::super::{
        possible_paste_key, replace_keyboard_paste, Event, KeyCode, Modifiers, NamedKey,
        PhysicalKey, WinitKey,
    };

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
