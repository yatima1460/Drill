# Offline source build

Download the `Drill-offline-source-<commit>` artifact from a successful **Offline source bundle** run on the pull request. Unzip the artifact, then extract its `Drill-source-<commit>.tar.gz`. The archive contains the committed workspace, the patched `vendor/eframe` library, and Cargo’s versioned copies of the locked registry crates and their distributed license files in `cargo-sources/`.

Install the Rust toolchain in `rust-toolchain.toml` and the SDK for your build machine before disconnecting. macOS needs the Xcode Command Line Tools. For Windows MSVC, install the C++ Build Tools and Windows SDK including `rc.exe`. On Ubuntu, install a C/C++ toolchain, pkg-config and the development packages for GTK 3, Wayland, xkbcommon, GL and EGL. Rebuilding the optional icon decoders also requires the pinned toolchain’s `wasm32-unknown-unknown` standard library.

From the extracted project root, run:

```sh
cargo build --release --frozen --bin drill
```

The result is `target/release/drill` (`drill.exe` on Windows). Cargo locates the bundled dependency sources through the relative path in `.cargo/config.toml`. You can set `CARGO_HOME` to an empty directory before building. Desktop builds embed the checked-in Wasm icon decoders.

To create an archive from a Git checkout, run `scripts/package-offline-source.sh`. It writes `dist/Drill-source-<commit>.tar.gz`. Pass a directory as the first argument to choose another destination. Creating the archive fetches any locked sources missing from Cargo's cache. Only committed files from `HEAD` enter the source snapshot.

The Ubuntu workflow builds and runs the desktop version command with networking disabled and a fresh Cargo home. It also resolves the separate proof workspace and rebuilds both Wasm decoders, remapping vendored crate paths to the registry paths embedded in the shipped Wasm before comparing the bytes. Desktop binary bytes can vary with the SDK, linker, platform and paths. Signing, packaging tools and the Kani verifier have their own setup instructions in [the development notes](rust-migration.md) and [verification guide](verification.md).

The Linux browser launcher opens two fixed HTTPS documentation links, both with ASCII hostnames. The desktop lockfile selects the ASCII-only `idna_adapter` 1.0.0 backend. This keeps the browser’s existing desktop and `BROWSER` handling and removes 21 ICU-related packages from the Linux release build. A general `cargo update` can select ICU again. When refreshing the lockfile, use `cargo update -p idna_adapter --precise 1.0.0` while Drill’s links stay fixed. Revisit this choice before accepting configurable URLs or internationalized hostnames, including Punycode labels. [Upstream backend selection](https://github.com/hsivonen/idna_adapter#turning-off-idna-support)
