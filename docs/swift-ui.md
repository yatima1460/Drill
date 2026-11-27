# Native macOS search window

Drill on macOS 13 or later uses SwiftUI and AppKit. To build from source, install the workspace Rust toolchain and the Xcode Command Line Tools. The app uses the system Swift runtime.

```sh
make build
make start
make test-ui
```

The local build produces `target/swift-ui/Drill.app` with the release bundle identifier `software.drill` and an ad-hoc signature. To search a fixture directory, run `target/swift-ui/Drill.app/Contents/MacOS/Drill --root /path/to/fixture`. Use `make package-macos` to create a disk image for the build machine’s architecture. For a disconnected machine, use the [offline source bundle](offline-build.md).

## How the window searches

SwiftUI owns the search field, selection and visible rows. The Rust adapter owns the search handle and uses the existing query parser, root discovery, macOS app filter and filesystem workers. Swift copies hits in bounded batches. Each hit carries the original path bytes for opening the file and a display name for the UI. Replacing a query drops the previous handle and cancels its workers. The C header defines pointer lifetimes and which thread may call each operation. [Search API](../crates/drill-swift/include/DrillSearch.h)

## Trying the interface

- Search Files or Apps, or leave Apps empty to list application bundles. Arrow keys select results and Return opens the selection. Stop keeps delivered rows. Continue retrieves the next page of 10,000 results. Escape from the main search window closes Drill.
- The AppKit table displays Name, Path, Size and Date with alternating row colors. Click a header to sort streaming results and drag a divider to resize a column. File icons come from macOS. For EXE and AppImage results, Drill reads embedded icons with the same two sandboxed Wasm decoders used on Windows and Linux.
- A row’s context menu can open it, choose another application, reveal it in Finder, open Terminal in its directory, or copy its full path, date or size. The menu retains the clicked file if another result moves into its row.
- **Settings → Interface** controls appearance and the two embedded-icon preferences. **Settings → Search** lets you include Photos library contents. This is off by default. **Settings → Permissions** adds selected folders for the session and opens the macOS privacy settings. **Help → Syntax** explains token, fuzzy, glob and regex searches.

The native interaction tests send events to a real AppKit window, read its accessibility tree, sample rendered row colors and icons, and exercise menu actions. The tests use a private pasteboard, temporary folders and injected application openers. They cover the chosen paths and actions. Manual VoiceOver interaction, system privacy grants, and Finder and Terminal opening on each supported macOS version are separate checks.

The native app stores interface preferences in macOS user defaults under `software.drill`. On first launch it carries over saved appearance and embedded-icon settings, preferring existing native settings, then Swift preview settings, then settings from the previous egui release. A fresh installation uses Auto appearance and enables both embedded-icon formats. You can change these in **Settings → Interface**. When upgrading from egui, the native window uses its own geometry and zoom defaults.

## Measuring compilation

On the same Mac, time egui from the Cargo invocation through the linked executable, and SwiftUI from the build command through the linked, assembled and ad-hoc-signed app. Swift and Rust compile concurrently against a small C header. The SDK module cache can materially affect a clean Swift build, so measure both an empty SDK cache and a previously populated SDK cache. Use fresh project and Cargo compiler outputs for every run, including the warm SDK condition. The [benchmark PR](https://github.com/yatima1460/Drill/pull/153) records the individual measurements and feature coverage.

To reproduce the historical comparison, supply a clean checkout of the former frontend and a checkout of the current native app. Choose a new output filename for each experiment.

```sh
python3 scripts/bench-swift-ui.py /path/to/previous-egui-checkout . --jobs 12 --runs 4 --output /tmp/drill-swift-builds.json
```

The runner alternates the three conditions, measures local signing and bundle assembly for the Swift app, and retains the Cargo timing reports beside the JSON. It checks the architecture, deployment target, app version and both embedded Wasm modules in every executable. It requires the Rust and SDK toolchains and cached Cargo sources. Filesystem pages and the installed Apple SDK are shared between samples.
