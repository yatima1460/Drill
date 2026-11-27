use drill_windows::clipboard;
use egui::{ColorImage, PlatformOutput};
use image::{codecs::png::PngEncoder, ExtendedColorType, ImageEncoder};
use raw_window_handle::{HasWindowHandle, RawWindowHandle};
use std::num::NonZeroIsize;
use winit::window::Window;

pub(super) use clipboard::read_text;

fn write_text(owner: NonZeroIsize, text: &str) {
    if !clipboard::write_text(owner, text) {
        log::error!("Could not copy text to the Windows clipboard");
    }
}

fn write_image(owner: NonZeroIsize, image: &ColorImage) -> bool {
    let [width, height] = image.size;
    let (Ok(png_width), Ok(png_height)) = (u32::try_from(width), u32::try_from(height)) else {
        return false;
    };
    let Some(pixels) = super::straight_rgba(image) else {
        return false;
    };
    let mut png = Vec::new();
    let encoded = PngEncoder::new(&mut png).write_image(
        &pixels,
        png_width,
        png_height,
        ExtendedColorType::Rgba8,
    );
    clipboard::write_rgba(
        owner,
        width,
        height,
        &pixels,
        encoded.is_ok().then_some(png.as_slice()),
    )
}

pub(super) fn copy_to_clipboard(window: &Window, mut output: PlatformOutput) -> PlatformOutput {
    let Ok(handle) = window.window_handle() else {
        return output;
    };
    let RawWindowHandle::Win32(handle) = handle.as_raw() else {
        return output;
    };

    super::write_clipboard_commands(
        &mut output,
        false,
        |text| write_text(handle.hwnd, text),
        |image| {
            if !write_image(handle.hwnd, image) {
                log::error!("Could not copy image to the Windows clipboard");
            }
        },
    );
    output
}

#[cfg(any(test, feature = "drill-clipboard-tests"))]
pub mod tests {
    use super::super::{
        possible_paste_key, replace_keyboard_paste, write_clipboard_commands, Event, KeyCode,
        Modifiers, NamedKey, OutputCommand, PhysicalKey, WinitKey,
    };
    use super::*;
    use std::cell::RefCell;

    /// Verify Windows paste shortcuts without accessing the system clipboard.
    #[cfg_attr(test, test)]
    pub fn windows_paste_shortcuts_preserve_copy_precedence() {
        let control = Modifiers::CTRL | Modifiers::COMMAND;
        let insert = PhysicalKey::Code(KeyCode::Insert);
        let logical_insert = WinitKey::Named(NamedKey::Insert);
        assert!(possible_paste_key(
            control,
            &WinitKey::Character("v".into()),
            insert
        ));
        assert!(possible_paste_key(
            Modifiers::SHIFT,
            &logical_insert,
            insert
        ));
        assert!(!possible_paste_key(control, &logical_insert, insert));
        assert!(possible_paste_key(
            Modifiers::NONE,
            &WinitKey::Named(NamedKey::Paste),
            insert
        ));

        let mut events = vec![Event::Copy];
        replace_keyboard_paste(&mut events, 0, || {
            panic!("Ctrl+Shift+Insert already emitted Copy")
        });
        assert!(matches!(&events[..], [Event::Copy]));
        replace_keyboard_paste(&mut events, 1, || Some(Some("ž 🌲\r\nline\r".into())));
        assert!(matches!(&events[..], [Event::Copy, Event::Paste(text)] if text == "ž 🌲\nline\r"));
    }

    /// Verify that text and images reach the native adapter in output order.
    #[cfg_attr(test, test)]
    #[allow(deprecated)]
    pub fn windows_clipboard_commands_keep_output_order() {
        let mut output = PlatformOutput {
            commands: vec![
                OutputCommand::CopyText("cut".to_owned()),
                OutputCommand::CopyImage(ColorImage::new([1, 1], egui::Color32::WHITE)),
                OutputCommand::CopyText("copy".to_owned()),
            ],
            copied_text: "legacy".to_owned(),
            ..PlatformOutput::default()
        };
        let writes = RefCell::new(Vec::new());
        write_clipboard_commands(
            &mut output,
            false,
            |text| writes.borrow_mut().push(text.to_owned()),
            |_| writes.borrow_mut().push("image".to_owned()),
        );
        assert_eq!(writes.into_inner(), ["cut", "image", "copy", "legacy"]);
        assert!(output.commands.is_empty());
        assert!(output.copied_text.is_empty());
    }
}
