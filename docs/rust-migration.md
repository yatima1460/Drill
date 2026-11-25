# Rust migration

The `rust` branch introduces a native Rust desktop application. The former Python implementation remains in Git history.

Run `cargo run --release` or open `Start Drill.command` on macOS. The launcher requires Rust installed through rustup. The first build may download dependencies.

The Rust search code runs off the UI thread, scans the existing platform root lists without indexing, and skips directory symlinks. Queries are case and accent insensitive; prefix a query with `fuzzy:` for approximate word matching. Results can be opened or revealed from the context menu. Search → Stop cancels an active or starting search and retains the results already shown. macOS and Windows use native application menus; Linux shows the menu inside the window.

Development checks: `cargo fmt --check`, `cargo check --locked`, `cargo clippy --locked --all-targets -- -D warnings`, and `cargo test --locked`.

CI builds a macOS DMG, Windows x86-64 ZIP, and Linux Debian, Arch, and AppImage packages. Windows is cross-compiled on Linux; the archive is inspected there but still requires a native Windows runtime check. macOS bundles are unsigned and not notarized. The AppImage relies on compatible system graphics libraries. Publishing runs only after all platform build jobs succeed on a push to main.

The search core forbids unsafe Rust. The desktop crate denies unsafe Rust except for its narrowly scoped Windows native Open With, COM, and window-menu calls. CI checks for undocumented unsafe blocks in the workspace targets it builds. Focused tests cover matching, priority, overlapping roots, completion and cancellation with a full result queue. Formal verification is not yet configured; the present filesystem, OS, GUI and packaging boundaries would not be established by a small bounded proof.

On macOS, `Run Core Tests.command` runs the independent search package tests. `Run UI Tests.command` runs the headless egui tests followed by an actual native-window test that moves the mouse and types; grant Accessibility access to the terminal running it if macOS requests it. Do not use the mouse or keyboard while that test runs. Linux CI runs that same native test on a virtual X display. The native test driver is enabled only for test builds.
