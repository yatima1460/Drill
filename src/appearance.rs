use eframe::egui::{Context, SystemTheme, ThemePreference, Ui, ViewportCommand};

const STORAGE_KEY: &str = "appearance";

pub(super) fn load(storage: Option<&dyn eframe::Storage>) -> ThemePreference {
    storage
        .and_then(|storage| eframe::get_value(storage, STORAGE_KEY))
        .unwrap_or(ThemePreference::System)
}

pub(super) fn save(storage: &mut dyn eframe::Storage, preference: ThemePreference) {
    eframe::set_value(storage, STORAGE_KEY, &preference);
}

pub(super) fn apply(ctx: &Context, preference: ThemePreference) {
    ctx.set_theme(preference);
    let window_theme = match preference {
        ThemePreference::System => SystemTheme::SystemDefault,
        ThemePreference::Light => SystemTheme::Light,
        ThemePreference::Dark => SystemTheme::Dark,
    };
    ctx.send_viewport_cmd(ViewportCommand::SetTheme(window_theme));
}

pub(super) fn controls(ui: &mut Ui, preference: &mut ThemePreference) {
    let previous = *preference;
    ui.horizontal(|ui| {
        ui.label("Appearance");
        ui.radio_value(preference, ThemePreference::System, "Auto")
            .on_hover_text("Follow the system appearance");
        ui.radio_value(preference, ThemePreference::Light, "Light");
        ui.radio_value(preference, ThemePreference::Dark, "Dark");
    });
    if *preference != previous {
        apply(ui.ctx(), *preference);
    }
}
