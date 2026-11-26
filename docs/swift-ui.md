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

## Measuring compilation

Measure the time from starting a clean release build to a linked executable on the same Mac. Include Rust compilation, Swift compilation, and final linking. Swift and Rust can compile concurrently against a small C header. The SDK module cache can materially affect a clean Swift build, so measure both an empty SDK cache and a previously populated SDK cache. Use fresh project and Cargo compiler outputs for every run, including the warm SDK condition. The [benchmark PR](https://github.com/yatima1460/Drill/pull/153) records the individual measurements and feature coverage.
