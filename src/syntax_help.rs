use eframe::egui;

const MODES: &[(&str, &str, &[&str])] = &[
    (
        "Words",
        "Every word must occur somewhere in the name, in any order. Case and accents are ignored. Punctuation such as dots, question marks and quotes is literal.",
        &["project notes"],
    ),
    (
        "Fuzzy words",
        "Each query word must resemble a word in the name. Use this for approximate spellings. Case and accents are ignored.",
        &["fuzzy:projecx notes"],
    ),
    (
        "Wildcards",
        "Match the whole name. An asterisk (*) matches any number of characters, a question mark (?) matches one, [0-9] matches a digit, and {jpg,png} offers alternatives. Case and accents are ignored. Use a backslash to escape a wildcard.",
        &["*.md", "glob:page[0-9]?.pdf", r"glob:literal\*.txt"],
    ),
    (
        "Regular expressions",
        "A Rust regex can match anywhere in the name. Use ^ for the start and $ for the end. Matching ignores case by default and preserves accents. Add (?-i) for case-sensitive matching.",
        &[r"regex:^IMG_[0-9]{4}\.jpg$"],
    ),
];

enum Reference {
    Glob,
    Regex,
}

impl Reference {
    fn link(self) -> (&'static str, &'static str) {
        match self {
            Self::Glob => (
                "Wax glob reference",
                "https://github.com/olson-sean-k/wax/blob/v0.7.0/README.md#patterns",
            ),
            Self::Regex => (
                "Rust regex reference",
                "https://docs.rs/regex/1/regex/#syntax",
            ),
        }
    }
}

#[cfg(target_os = "linux")]
fn reference_link(ui: &mut egui::Ui, reference: Reference) {
    let (label, url) = reference.link();
    ui.hyperlink_to(label, url);
}

#[cfg(not(target_os = "linux"))]
fn reference_link(ui: &mut egui::Ui, reference: Reference) {
    let (label, url) = reference.link();
    let response = ui.link(label);
    if response.clicked() || response.middle_clicked() {
        std::thread::spawn(move || {
            #[cfg(windows)]
            let result =
                super::with_shell_sta(|| super::launch_windows_app(std::path::Path::new(url)));
            #[cfg(not(windows))]
            let result = {
                let program = if cfg!(target_os = "macos") {
                    "/usr/bin/open"
                } else {
                    "xdg-open"
                };
                std::process::Command::new(program)
                    .arg(url)
                    .status()
                    .map_err(|e| e.to_string())
                    .and_then(|status| {
                        if status.success() {
                            Ok(())
                        } else {
                            Err(status.to_string())
                        }
                    })
            };
            if let Err(error) = result {
                eprintln!("Could not open {url}: {error}");
            }
        });
    }
    if ui.style().url_in_tooltip {
        response.on_hover_text(url);
    }
}

/// Returns true when the reader dismisses the dialog.
pub(super) fn show(ctx: &egui::Context) -> bool {
    let modal = egui::Modal::new(egui::Id::new("syntax_help"));
    let opening = ctx.memory(|memory| memory.top_modal_layer() != Some(modal.area.layer()));
    let screen = ctx.screen_rect();
    let response = modal.show(ctx, |ui| {
        ui.set_width((screen.width() - 48.0).clamp(60.0, 460.0));
        let dismiss = ui.horizontal(|ui| {
            ui.heading("Search syntax");
            ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                ui.button("×").on_hover_text("Close").clicked()
            })
            .inner
        }).inner;
        ui.separator();
        egui::ScrollArea::vertical()
            .max_height((screen.height() - 130.0).max(40.0))
            .show(ui, |ui| {
                for (heading, description, examples) in MODES {
                    ui.strong(*heading);
                    ui.label(*description);
                    for example in *examples {
                        ui.monospace(*example);
                    }
                    ui.add_space(6.0);
                }
                ui.label("Use lowercase prefixes at the start. Without a prefix, an asterisk selects wildcard search. Otherwise Drill searches for words.");
                ui.label("Files searches file and folder names. An empty Apps search lists applications. On Linux, Apps also matches launcher IDs, filenames and keywords.");
                ui.label("Invalid patterns show an error. Globs and regexes accept up to 4,096 bytes. Glob groups can nest up to eight levels.");
                ui.collapsing("More pattern syntax", |ui| {
                    ui.label("In a glob, [!0-9] matches one character other than a digit. <[0-9]:4> matches exactly four digits. The $ wildcard is a lazy version of *.");
                    reference_link(ui, Reference::Glob);
                    ui.label("In a regex, use | for alternatives, parentheses for groups, and + to repeat the preceding item one or more times. Rust regexes exclude look-around and backreferences.");
                    reference_link(ui, Reference::Regex);
                });
            });
        ui.separator();
        let close = ui.button("Close");
        if opening {
            close.request_focus();
        }
        dismiss || close.clicked()
    });
    let escape = ctx.input_mut(|input| input.consume_key(egui::Modifiers::NONE, egui::Key::Escape));
    response.inner || escape
}

#[cfg(test)]
mod tests {
    use super::{Reference, MODES};
    use drill_core::SearchQuery;

    #[test]
    fn help_urls_have_fixed_ascii_https_hosts() {
        for (reference, host) in [
            (Reference::Glob, "github.com"),
            (Reference::Regex, "docs.rs"),
        ] {
            let (_, url) = reference.link();
            assert!(url.bytes().all(|byte| byte.is_ascii_graphic()));
            let (authority, _) = url
                .strip_prefix("https://")
                .unwrap()
                .split_once('/')
                .unwrap();
            assert_eq!(authority, host);
        }
    }

    #[test]
    fn help_examples_match_their_intended_names() {
        let filenames = [
            ("Nôtés for the project.txt", "Project schedule.txt"),
            ("Project Notes.txt", "Inventory.csv"),
            ("README.MD", "notes.md.bak"),
            ("Page3猫.pdf", "Page32x.pdf"),
            ("literal*.txt", "literal1.txt"),
            ("img_0027.JPG", "IMG_27.jpg"),
        ];
        let examples = MODES.iter().flat_map(|(_, _, examples)| *examples);
        assert_eq!(examples.clone().count(), filenames.len());
        for (example, (hit, miss)) in examples.zip(filenames) {
            let query = SearchQuery::parse(example);
            assert!(query.error().is_none(), "{example}");
            assert!(
                query.classify(hit).is_some(),
                "{example} should match {hit}"
            );
            assert!(
                query.classify(miss).is_none(),
                "{example} should skip {miss}"
            );
        }
    }
}
