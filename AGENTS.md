# Working on Drill

Drill is a Rust desktop file searcher for macOS, Windows and Linux. It streams results while walking the filesystem. Use the workspace's pinned Rust toolchain and committed lockfile. See the [development and platform notes](docs/rust-migration.md) and the [RustProject template](https://github.com/yatima1460/RustProject/blob/main/AGENTS.md).

## Collaboration and delivery

For each request involving the repository, assign planning to the strongest available model at its maximum supported reasoning effort. This planning coordinator prepares the plan before implementation. As of November 2026, the example is Astra at Ultra reasoning effort. The implementation coordinator owns delivery, integration and validation. Give research and review agents read-only tasks by default. Delegate independent implementation in separate worktrees with explicit file ownership and stable interfaces.

Open a pull request and ask an independent reviewer selected by the same model and effort rule to review the actual PR. Immediately before every merge, recheck the PR conversation, submitted reviews and inline review threads for comments from automated AI reviewers, including Codex. Address substantive findings, then confirm the reviewed head still matches and the required checks pass before merging. Respect requests for a draft or to leave a PR open. If a required review or GitHub operation is unavailable, report the blocker. Read-only questions can be answered directly.

## External dependencies and platform bindings

Be as native as possible on each supported platform. Follow its desktop conventions and call its documented SDK directly through small bindings for the exact operations Drill needs. On macOS, use Apple's SDKs for integrations such as menus, the clipboard, and file icons. Keep platform bindings at the edge of the application and use the standard library for shared search behavior. If a replacement would require recreating a general-purpose library, explain the tradeoff to the user.

Use an external dependency only when it is strictly necessary. **Always ask the user and wait for explicit approval before adopting one.** Explain which behavior needs it and why the standard library or a narrow binding is insufficient. This also applies to build and test dependencies, vendored code, and direct use of a package already present transitively.

## Design and behavior

- Prefer a functional core. Keep matching and ranking deterministic where practical, pass inputs explicitly, and isolate filesystem, platform and rendering effects. Choose ownership and bounded work that make behavior easy to parallelize, test and verify.
- `crates/drill-query` owns parsing, normalization and filename matching. `crates/drill-core` reexports its query API and owns app file filters, directory priority, traversal, and delivery of results. Keep filesystem calls outside the shared directory-queue lock. Changes to traversal should account for overlapping roots, symlinks, unreadable directories, and cancellation while paused or while the result queue is full.
- `src/main.rs` and its sibling modules own the egui interface and platform integration. Exercise changes through the search box, Files/Apps selector, or other affected entry point. Preserve result identity through streaming, sorting and selection. Check that new queries discard stale results and that Continue resumes the same scan.
- Keep changes scoped. Reuse existing interfaces and extract a module or crate when it gives the project a concrete testing, ownership or build benefit. Consult the local patch notes before changing vendored libraries.

### Why icon decoding uses WebAssembly

Displaying a search result can make Drill parse an icon from an untrusted file before the user opens it. Keep this parsing in bundled WebAssembly (Wasm) decoders so a parser bug has limited access to the desktop process and a malformed icon has a bounded memory and execution budget. The search engine and desktop UI run natively.

The [Windows executable decoder](tools/exe-icon-wasm) receives a size-limited copy of the file and imports no host functions. The [AppImage decoder](tools/appimage-icon-wasm) can request only bounded reads from the file Drill already opened. The host reads back a fixed-size RGBA icon without running the discovered executable or mounting the AppImage. If decoding fails or exceeds a limit, preserve the file-type icon or generic glyph fallback.

## Validation

Run the least expensive checks that exercise the changed behavior, followed by the required CI checks. The [Makefile](Makefile) defines the commands.

| Change | Relevant check |
| --- | --- |
| Matching, traversal or cancellation | `make test-core` with a focused fixture |
| Keyboard, pointer, rendering or result-list behavior | `make test-ui-headless` drives egui frames. `make test-ui-native` drives a real window and OS input. Use a controlled desktop for the native test. Linux CI uses Xvfb. |
| Rust integration | `make fmt-check check lint test` |
| Scripts and packaging | `make shellcheck` and the affected packaging target. Inspect the artifact a user would download. |

For a bug fix, demonstrate the regression against the previous revision when practical. For performance work, record the fixture, cache state, worker count and timing boundaries. Measure time to the first useful result as well as completion.

For investigations with competing explanations, keep a short hypothesis tree in the PR or investigation notes. Start with the objective and baseline. For each alternative, record its predicted outcome, the test that could disprove it, the revision or artifact, and the result. Use what you learn from unsuccessful trials to choose the next experiment. Before adopting a change, check it against an independent fixture, platform, or clean benchmark that was not used to tune it. This adapts the method in [Toward Generalist Autonomous Research via Hypothesis-Tree Refinement (PDF)](https://arxiv.org/pdf/2606.11926).

Use property tests, mutation testing, fuzzing or bounded proofs for the contracts each can check. Record proof assumptions, input domains and unwinding bounds. Review surviving mutants and counterexamples. Preserve the meaning of tests, assertions and CI gates when making a change.

## Desktop release profile

Keep desktop releases at optimization level 3 with `lto = "off"` and Cargo's default codegen-unit count. On an Apple M6 with 12 build jobs, a clean build took 20.54 s with the previous default release profile and 41.84 s with fat LTO and one codegen unit. In 24 paired searches over 32,769 files, median first-query completion improved from 26.52 ms to 25.24 ms. A repeated query improved from 10.49 ms to 10.34 ms. Median time to a visible window was 206.83 ms versus 208.48 ms across 16 pairs. These marginal runtime gains did not justify the clean-build cost for Drill.

The comparison changed both LTO and codegen units. The earlier control used Cargo's default, which permits crate-local ThinLTO. Reconsider the desktop profile when representative startup or search measurements show a larger benefit. The independent Wasm decoder profiles optimize for embedded code size.

## Platform and release evidence

Consult the [release workflow](.github/workflows/rust.yml) before reporting platform coverage. A Windows cross-build, a Wine smoke test and a native Windows run establish different things. The macOS preview build and production signing are separate jobs. Keep signing credentials in the protected production environment and ordinary PR validation independent of those credentials.

Report what actually ran, what passed, and what remains unverified. Link the PR and relevant test, release or benchmark evidence.
