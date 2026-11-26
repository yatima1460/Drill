# Working on Drill

Drill is a Rust desktop file searcher for macOS, Windows and Linux. It streams results while walking the filesystem. Use the workspace's pinned Rust toolchain and committed lockfile. See the [development and platform notes](docs/rust-migration.md) and the [RustProject template](https://github.com/yatima1460/RustProject/blob/main/AGENTS.md).

## Collaboration and delivery

For each request involving the repository, ask Astra with Ultra reasoning for a plan before implementation. The coordinator owns implementation, integration and validation. Give research and review agents read-only tasks by default. Delegate independent implementation in separate worktrees with explicit file ownership and stable interfaces.

Open a pull request and ask Astra Ultra to review the actual PR. Check GitHub review threads, including Codex comments, and resolve substantive findings. Merge after a satisfactory review and passing required checks. Respect requests for a draft or to leave a PR open. If a required review or GitHub operation is unavailable, report the blocker. Read-only questions can be answered directly.

## Design and behavior

- Prefer a functional core. Keep matching and ranking deterministic where practical, pass inputs explicitly, and isolate filesystem, platform and rendering effects. Choose ownership and bounded work that make behavior easy to parallelize, test and verify.
- `crates/drill-core` owns query matching, app file filters, directory priority, traversal, and delivery of results. Keep filesystem calls outside the shared directory-queue lock. Changes to traversal should account for overlapping roots, symlinks, unreadable directories, and cancellation while paused or while the result queue is full.
- `src/main.rs` and its sibling modules own the egui interface and platform integration. Exercise changes through the search box, Files/Apps selector, or other affected entry point. Preserve result identity through streaming, sorting and selection. Check that new queries discard stale results and that Continue resumes the same scan.
- File names, icons and executable resources come from the filesystem. Keep parsing bounded and preserve fallback behavior for unreadable or malformed input. The executable icon decoder lives in [its own Wasm package](tools/exe-icon-wasm). Consult the local patch notes before changing vendored libraries.
- Keep changes scoped. Reuse existing interfaces and extract a module or crate when it gives the project a concrete testing, ownership or build benefit.

## Validation

Run the least expensive checks that exercise the changed behavior, followed by the required CI checks. The [Makefile](Makefile) defines the commands.

| Change | Relevant check |
| --- | --- |
| Matching, traversal or cancellation | `make test-core` with a focused fixture |
| Keyboard, pointer, rendering or result-list behavior | `make test-ui-headless` drives egui frames. `make test-ui-native` drives a real window and OS input. Use a controlled desktop for the native test. Linux CI uses Xvfb. |
| Rust integration | `make fmt-check check lint test` |
| Scripts and packaging | `make shellcheck` and the affected packaging target. Inspect the artifact a user would download. |

For a bug fix, demonstrate the regression against the previous revision when practical. For performance work, record the fixture, cache state, worker count and timing boundaries. Measure time to the first useful result as well as completion. For complicated investigations, record the hypothesis, the observation that would distinguish it, and the result alongside its commit or artifact. Reuse that evidence when choosing the next experiment. This adapts an approach explored in [Toward Generalist Autonomous Research via Hypothesis-Tree Refinement](https://arxiv.org/abs/2606.11926).

Use property tests, mutation testing, fuzzing or bounded proofs for the contracts each can check. Record proof assumptions, input domains and unwinding bounds. Review surviving mutants and counterexamples. Preserve the meaning of tests, assertions and CI gates when making a change.

## Platform and release evidence

Consult the [release workflow](.github/workflows/rust.yml) before reporting platform coverage. A Windows cross-build, a Wine smoke test and a native Windows run establish different things. The macOS preview build and production signing are separate jobs. Keep signing credentials in the protected production environment and ordinary PR validation independent of those credentials.

Report what actually ran, what passed, and what remains unverified. Link the PR and relevant test, release or benchmark evidence.
