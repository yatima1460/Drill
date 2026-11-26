# Native macOS search window

The SwiftUI experiment for [issue #158](https://github.com/yatima1460/Drill/issues/158) runs alongside the released desktop app. It builds with the workspace Rust toolchain and Apple's macOS SDK, using the system Swift runtime. The minimum deployment target is macOS 13.

```sh
make build-swift-ui
make start-swift
make test-swift-ui
```

The app is written to `target/swift-ui/Drill Swift.app`. It has a separate bundle identifier, `software.drill.swift-preview`, and an ad-hoc signature for local execution. To try a single fixture directory, invoke its executable with `--root` followed by the directory path. For a disconnected machine, use the [offline source bundle](offline-build.md) and run `CARGO_NET_OFFLINE=true make build-swift-ui`.

## How the window searches

SwiftUI owns the search field, selection and visible rows. The Rust adapter owns the search handle and uses the existing query parser, root discovery, macOS app filter and filesystem workers. Swift copies hits in bounded batches. Each hit carries the original path bytes for opening the file and a display name for the UI. Replacing a query drops the previous handle and cancels its workers. The C header defines pointer lifetimes and which thread may call each operation. [Search API](../crates/drill-swift/include/DrillSearch.h)

## Trying the interface

- Search Files or Apps, or leave Apps empty to list application bundles. Arrow keys select results and Return opens the selection. Stop keeps delivered rows. Continue retrieves the next page of 10,000 results. Escape from the main search window closes Drill.
- The AppKit table displays Name, Path, Size and Date with alternating row colors. Click a header to sort streaming results and drag a divider to resize a column. File icons come from macOS. The two embedded-icon formats use the same sandboxed decoders as the egui app.
- A row’s context menu can open it, choose another application, reveal it in Finder, open Terminal in its directory, or copy its full path, date or size. The menu retains the clicked file if another result moves into its row.
- **Settings → Interface** controls appearance and the two embedded-icon preferences. **Settings → Permissions** adds selected folders for the session and opens the macOS privacy settings. **Help → Syntax** explains token, fuzzy, glob and regex searches.

The native interaction tests send events to a real AppKit window, read its accessibility tree, sample rendered row colors and icons, and exercise menu actions. The tests use a private pasteboard, temporary folders and injected application openers. They cover the chosen paths and actions. Manual VoiceOver interaction, system privacy grants, and Finder and Terminal opening on each supported macOS version are separate checks. The preview has its own preferences and macOS permission identity. It does not import egui’s saved window state or zoom.

## Measuring compilation

On the same Mac, time egui from the Cargo invocation through the linked executable, and SwiftUI from the build command through the linked, assembled and ad-hoc-signed app. Swift and Rust compile concurrently against a small C header. The SDK module cache can materially affect a clean Swift build, so measure both an empty SDK cache and a previously populated SDK cache. Use fresh project and Cargo compiler outputs for every run, including the warm SDK condition. The [benchmark PR](https://github.com/yatima1460/Drill/pull/153) records the individual measurements and feature coverage.

From a clean PR checkout, run the following command to compare the two interfaces from the same revision. Choose a new output filename for each experiment.

```sh
python3 scripts/bench-swift-ui.py . . --jobs 12 --runs 4 --output /tmp/drill-swift-builds.json
```

The runner alternates the three conditions, measures local signing and bundle assembly for the Swift app, and retains the Cargo timing reports beside the JSON. It checks the architecture, deployment target, app version and both embedded Wasm modules in every executable. It requires the Rust and SDK toolchains and cached Cargo sources. Filesystem pages and the installed Apple SDK are shared between samples.
