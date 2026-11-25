# Rust migration

The `rust` branch introduces a native Rust desktop application. The former Python implementation remains in Git history.

Run `cargo run --release` or open `Start Drill.command` on macOS. The launcher requires Rust installed through rustup. The first build may download dependencies.

The Rust search code runs off the UI thread, scans the existing platform root lists without indexing, and skips directory symlinks. Queries are case and accent insensitive; prefix a query with `fuzzy:` for approximate word matching. Results can be opened or revealed from the context menu.

Development checks: `cargo fmt --check`, `cargo check --locked`, `cargo clippy --locked --all-targets -- -D warnings`, and `cargo test --locked`.

Existing downloadable releases predate the Rust version. Rust release packaging and UI parity must be verified on Windows, Linux, and macOS before shipping.
