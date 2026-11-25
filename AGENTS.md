# RustProject — instructions for AI coding agents

Build a small, understandable Rust project with fast feedback, explicit boundaries, and independently checkable behavior. The motivating application is a portable 2D game, but the engineering rules also apply to other Rust projects.

**Project status:** Drill is a desktop file search application. The Rust migration uses one Cargo package with the search core in `src/search.rs` and the desktop UI in `src/main.rs`. Legacy Python releases remain in Git history; Rust release packaging is not yet implemented. See `docs/rust-migration.md` for current commands and platform limitations. Game-specific examples below are general guidance, not requirements for Drill.

## Required collaboration and delivery workflow

For every user request involving repository work, ask an Astra agent with Ultra reasoning to prepare a plan before implementation. The coordinating agent implements the work, runs the appropriate checks, and opens a pull request. Ask Astra Ultra to review the actual pull request and resolve its substantive findings; merge only after the review is satisfactory and required checks pass. Follow the user's instructions on scope and delivery, and do not merge when the user asks for a draft or otherwise says not to merge. If Astra Ultra or a required GitHub operation is unavailable, report the blocker rather than claiming the review or merge happened. Read-only answers do not require a pull request.

## 1. Operating contract — read for every task

1. **Establish the task.** Read the relevant specification, existing code, and local instructions. Identify the smallest useful change, the allowed write scope, and observable acceptance criteria. Continue authorized work without repeatedly asking for permission; ask only when a consequential ambiguity cannot be resolved from the project.
2. **Preserve boundaries.** Keep domain rules independent of rendering and I/O. Use narrow interfaces and private internals. Do not change unrelated subsystems or introduce abstractions without a concrete need.
3. **Use evidence.** Compile, run the relevant tests, and inspect runtime output where applicable. A successful build, an AI review, and a mathematical proof establish different things; report exactly which evidence exists.
4. **Delegate conservatively.** Follow the required Astra planning and review workflow above; subagents are otherwise read-only by default: research, analysis, review, and proposed patches. Allow implementation subagents only for trivially parallelizable work with explicit ownership and isolated workspaces. One coordinator owns integration.
5. **Finish honestly.** Deliver the requested result with a concise account of changes, validation, and remaining limitations. Never make a check pass by silently weakening requirements, deleting assertions, disabling gates, or approving a new screenshot baseline.

The sections below are conditional guidance. A documentation edit does not require fuzzing, formal proofs, a GPU matrix, or multiple agents. Use the cheapest checks that resolve the actual risk, plus the repository's required gates.

| Work being done | Read next |
| --- | --- |
| New feature or architecture change | Sections 2–4 |
| Slow iteration or build configuration | Section 5 |
| Graphics, browser build, or platform support | Sections 6–7 |
| Agent execution or delegation | Sections 8–9 |
| Tests, proofs, reviews, or CI | Sections 10–12 |

## 2. Baseline stack and project decisions

Use stable Rust and Cargo for normal development. Pin the selected toolchain in `rust-toolchain.toml`, commit `Cargo.lock` for the application, and use compatible dependency versions. Use rust-analyzer for navigation and diagnostics, rustfmt for formatting, and Clippy for linting. Keep specialized nightly or verification toolchains separate from the normal build.

For a custom portable renderer, prefer **wgpu + WGSL + winit**. Use **cargo-nextest** for ordinary native tests once configured, with **Proptest** for meaningful domain properties. Add fuzzing, mutation testing, Kani, or Verus when a particular risk justifies their setup and maintenance.

Rust is a project choice, not a proven first-place ranking for AI-generated correctness. Safe Rust provides strong memory-safety constraints under its safety assumptions; it does not establish correct rules, good UX, bounded resource usage, or correct shaders. Do not choose raw Metal, Vulkan, or Direct3D based on an unsupported claim that models generate one API more reliably.

Maintain project decisions in `docs/`: behavior specifications, architecture decisions, supported platforms, and reproducible development commands. Keep one authoritative description of each decision. Do not copy large, competing specifications into every prompt.

Game examples in this guide, including biomass and card actions, illustrate verification techniques. They are not a replacement for the game's accepted design document.

## 3. Architecture: cohesive components with enforced interfaces

Start with a small workspace or a small package. A useful eventual workspace has `game-core` and `game-app`; extract `game-render` only when a separate renderer library improves reuse, ownership, testing, or build behavior. Do not create a crate per card, type, or minor feature.

| Component | Owns | Boundary |
| --- | --- | --- |
| `game-core` | Valid states, commands, rule evaluation, state transitions | No dependency on the renderer, windowing, filesystem, network, or platform SDKs |
| Rendering module or `game-render` | Draw preparation, assets needed for drawing, GPU resources | Receives an immutable view or snapshot; cannot mutate authoritative game state |
| Platform adapters | Input translation, persistence, clocks, audio, browser/native integration | Convert external data into validated domain inputs; contain platform-specific code |
| `game-app` | Startup, event loop, subsystem coordination | Composes components without duplicating game rules |

Keep state and its rules together when splitting them would create cycles or meaningless indirection. A separate state crate is not a requirement.

### Domain model and state transitions

1. Use explicit commands such as `PlayCard`, `Attack`, and `EndTurn`, with typed validation errors. A rejected command must leave the authoritative state unchanged when that is the specified contract.
2. Keep transitions deterministic: pass randomness explicitly, record its seed or state, and isolate time and I/O. A seed alone is insufficient if iteration order, floating-point behavior, or RNG versions vary; define the reproducibility scope.
3. Give one component ownership of state changes. Rendering, animation, and sound consume results or events; they do not secretly apply gameplay effects.
4. Prefer private fields, checked constructors, enums for phases, and small domain types for identifiers and quantities. Serialization boundaries must validate invariants rather than bypassing constructors.
5. Make replay possible through recorded commands and relevant version/seed information. Use small deterministic fixtures for debugging, regression tests, and screenshots.

### Boundaries must be enforceable

Rust visibility hides implementation details; `pub(crate)` exposes an item throughout its crate, not just to a chosen sibling module. Use the narrowest suitable visibility. Expose contracts, not mutable internals or platform types.

Crate dependencies strengthen boundaries, but an agent can still edit `Cargo.toml` and introduce a forbidden dependency. When the dependency graph becomes important, check an allowed dependency policy using `cargo metadata` in CI and review manifest changes. Adding files alone does not prevent leaky abstractions.

Prefer straightforward ownership and explicit data flow. Do not solve design problems by scattering `Arc<Mutex<_>>`, global mutable state, `unsafe`, or broad `pub` access. Use concurrency or unsafe code only for a demonstrated requirement, with a documented contract and appropriate validation.

### Design patterns are optional tools

| Pattern | Useful application | Avoid |
| --- | --- | --- |
| Command and State | Replayable actions and explicit legal phases | Arbitrary mutation from UI callbacks |
| Strategy | Interchangeable algorithms using an enum, function, or trait | A trait hierarchy for a single implementation with no boundary to protect |
| Observer/events | Rendering or audio reacting to completed domain events | A global event bus with hidden ordering and recursive state changes |
| Adapters / functional core | Deterministic rules with I/O at the edges | Interfaces whose types expose every platform detail |

Introduce factories, visitors, dependency injection frameworks, or an ECS only when the application benefits. There is no requirement to reproduce the Gang of Four catalogue or maximize abstraction.

## 4. Instructions, context, and change discipline

Write instructions that convey project-specific decisions: module ownership, forbidden dependency directions, unusual setup, and exact validation commands. Generic personas such as “world-class rendering engineer” are not a substitute for scope or acceptance criteria.

This file is deliberately comprehensive because it captures the complete project guidance. Keep its operating contract concise. If the project later grows separate subsystem guides, link to them and avoid duplicating instructions. Sectioning a long root file does not itself reduce tokens when a harness loads the entire file.

Use narrow searches and read the relevant modules and contracts before editing. Preserve useful context in a short handoff: task, changed files, interface decisions, commands run, and unresolved questions. Avoid repeatedly rediscovering the whole repository.

Keep changes reviewable. Update a specification when behavior intentionally changes; do not quietly rewrite it to justify an implementation. Discuss an interface change with the coordinator before expanding a delegated task across modules. Prefer a concrete proposal to an unnecessary stop for routine implementation choices.

## 5. Fast Rust iteration

**Measure the edit–check–test loop before changing the architecture.** Rust crates are compilation units; modules organize code inside a crate. Splitting one source file into modules does not by itself create independent compilation units. More crates can improve some builds and worsen others. See the [Rust Reference](https://doc.rust-lang.org/reference/crates-and-source-files.html) and [Cargo build-performance guide](https://doc.rust-lang.org/cargo/guide/build-performance.html).

1. Use `cargo check -p <affected-package>` for early compiler feedback, then run focused tests. `cargo check` is not a substitute for linking and executing the application.
2. Keep local incremental artifacts and stable feature sets where practical. Do not routinely run `cargo clean`. Reduce unnecessary dependencies, feature activation, procedural macros, or generated code when measurement identifies them as the problem.
3. Measure representative builds with `cargo build --timings`. Distinguish clean builds, small-edit rebuilds, test compilation, linking, and actual test execution. Change one relevant setting at a time.
4. Tune development optimization, debug information, linker choice, and code generation only with before/after results. Preserve a usable debugging profile. Keep experimental nightly settings out of the default path unless the project deliberately adopts them.
5. Benchmark `sccache` for the actual workflow and pinned version; inspect hit rates. Local incremental compilation and CI compiler caches have different tradeoffs. See [sccache's Rust caveats](https://github.com/mozilla/sccache#rust).

Keep heavy graphics dependencies out of domain-only builds. Use target-specific dependency declarations and deliberate feature sets. Do not blindly enable every feature: some are platform-specific or mutually incompatible.

Limit simultaneous Cargo builds on the 32 GB development Mac. Reuse artifacts inside a trusted worker where appropriate; isolate target directories when parallel jobs would contend or require different settings. Cache keys must account for toolchain, target, profile, dependency lockfile, and relevant feature/compiler settings.

## 6. Portable native graphics

wgpu supplies the cross-platform graphics abstraction. Do not build a second custom Metal/Vulkan/D3D12 layer without a measured feature or performance requirement. WGSL is the default shader language for the shared renderer; winit handles windows and event loops, not rendering.

| Target | Intended graphics path |
| --- | --- |
| macOS and native iOS/iPadOS | wgpu Metal backend |
| Linux | wgpu Vulkan backend |
| Windows | wgpu D3D12 or Vulkan backend; document and test the selected default |
| Browser | Rust/WASM with wgpu WebGPU |
| Optional browser fallback | Explicitly configured and separately tested WebGL2 with reduced capabilities |

Consult the [wgpu support table](https://github.com/gfx-rs/wgpu#supported-platforms), [wgpu limits](https://docs.rs/wgpu/latest/wgpu/struct.Limits.html), and [winit documentation](https://docs.rs/winit/latest/winit/) for the versions being used. Platform coverage is not a promise of identical features, performance, or driver behavior.

1. Define the minimum supported features and limits. Request only what is needed, inspect adapter capabilities, and provide a useful unsupported-device message.
2. Log the selected adapter/backend for diagnostics. Validate shaders and pipeline creation, including buffer layout, alignment, texture formats, and color space.
3. Share drawing code between window presentation and render-to-texture tests. Isolate surface creation, resize, presentation, and device-loss recovery.
4. Respect each platform's event-loop, touch/input, suspend/resume, and asset-loading requirements. Native iOS packaging and signing require their own setup; wgpu does not provide an app distribution pipeline.
5. Profile on the intended target before optimizing. Set explicit CPU/GPU frame-time, memory, and startup budgets appropriate to the game; do not infer performance from language or backend names.

There is no need to route the default Apple build through a Vulkan-to-Metal translator when wgpu's Metal backend meets the requirements. Do not carry forward an unverified blanket claim that MoltenVK is deprecated.

## 7. WebAssembly, previews, and graphical verification

### Browser distribution

Add a `wasm32-unknown-unknown` build early enough to reveal incompatible dependencies. Share domain code and rendering routines; use platform adapters for persistence, asset loading, timing, input, and lifecycle. Avoid assumptions about ordinary filesystem access, unrestricted threads, or blocking the browser event loop.

Once a web entry point and assets are configured, [Trunk](https://trunk-rs.github.io/trunk/guide/commands/index.html) provides `trunk serve` for local development and `trunk build --release` for distributable web assets. The exact invocation belongs in the project's development documentation.

A localhost server is accessible on the developer's machine; sharing with a friend requires hosting the output or an explicitly configured temporary tunnel/network arrangement. Use HTTPS for deployment because [WebGPU requires a secure context](https://www.w3.org/TR/webgpu/); trustworthy localhost is the usual development exception. Verify target browsers, including Safari/iPad if promised. Do not assume a WebGL2 fallback is automatic or equivalent to WebGPU.

### Graphics inside a sandbox

| Check | Appropriate environment | What it does not establish |
| --- | --- | --- |
| Rules and deterministic simulation | Headless Linux VM/container | Graphics or platform behavior |
| Offscreen image rendering | wgpu adapter; software Vulkan can be useful in Linux | Real Metal/D3D12 behavior or window presentation |
| Window/input smoke test | Working display server/session; Xvfb for suitable X11 tests | That a real GPU is present |
| Release platform validation | Compatible real backend/device and usable session | Other platforms that were not exercised |

[Xvfb](https://xorg.freedesktop.org/releases/X11R6.8.2/doc/Xvfb.1.html) provides a virtual X display. It does not provide a Vulkan or Metal implementation. [Mesa Lavapipe](https://docs.mesa3d.org/sourcetree) is a software Vulkan option. Offscreen render-to-texture testing may need no display server at all.

Use fixed viewport sizes, fonts/assets, simulation time, and replay inputs for screenshots. Preserve actual images and difference images with explicit tolerances. Account for backend-specific rendering differences; do not blindly compare every GPU to one exact pixel baseline. Require review of intentional baseline changes.

Run Metal checks in a suitable Apple environment, and D3D12/Vulkan checks on suitable Windows/Linux runners. A standard Linux microVM on a Mac is not evidence of Metal coverage. Detect missing adapters and report tests as skipped or unavailable; required release coverage must not silently turn into a pass. Include actual window, touch/input, resize, and lifecycle checks beyond screenshots.

## 8. Sandboxing on the development Mac

Use a disposable, reproducible environment for autonomous command execution. Ordinary containers and separate virtual machines provide different isolation boundaries; on macOS, ordinary Docker containers typically run inside a shared Linux VM. Do not assume each container gets a separate kernel.

[Docker Sandboxes](https://docs.docker.com/ai/sandboxes/get-started/) is one suitable microVM option. Check the installed release's documentation rather than assuming old commands or defaults. Its documented [clone mode](https://docs.docker.com/ai/sandboxes/usage/) uses a private in-sandbox Git clone; the default direct workspace mode can modify the host working tree. Choose clone mode or an equivalent private-checkout workflow when isolation from the working tree is required.

1. Give a worker only the repository, task inputs, and tools it needs. Restrict network destinations and credentials to the task. Inspect what the selected sandbox actually shares.
2. Avoid mounting the host home directory, host Docker socket, signing keys, or unrelated workspaces. Treat forwarded SSH agents and host-side MCP tools as capabilities that cross the VM boundary.
3. Keep commits or patch artifacts before destroying a worker. A Git branch or worktree separates edits; it is not a security sandbox and does not by itself enforce path ownership.
4. Start with one worker on the 32 GB Mac. Set CPU/memory limits and measure memory pressure and build contention before adding concurrency; there is no guaranteed safe worker count from RAM alone.
5. For native GPU testing, use a controlled runner or test account with the required device/session and minimal credentials. Do not compensate for missing VM graphics by granting an unrestricted agent access to the personal desktop.

Follow the [sandbox security model](https://docs.docker.com/ai/sandboxes/security/). Isolation limits access; mounted files, allowed network operations, and exposed tools remain real capabilities.

## 9. Subagents: ownership contracts, not personalities

The default is one implementation coordinator with read-only research/review subagents. This is a project preference, not a claim that more agents always improve results.

Parallel implementation is appropriate only when tasks are trivially independent, have stable interfaces and non-overlapping write scopes, and can be integrated without simultaneous changes to shared contracts. Use separate branches/checkouts. Enforce restrictions with actual permissions or integration checks where available; prompt text alone is not enforcement.

A delegation brief must include:

1. The objective and concrete acceptance criteria.
2. Allowed writes and relevant read access; reading adjacent modules is usually useful.
3. Existing interfaces and how to report a required interface change.
4. Validation commands, evidence to return, and a time/token budget where appropriate.
5. Who integrates the result and how conflicts or unexpected scope are handled.

Example for an authorized, independent renderer change:

> Implement card layout in the assigned rendering module. Read domain interfaces as needed; do not modify domain rules, manifests, or public contracts. Consume the existing immutable view. Run the focused layout checks and capture the agreed deterministic scene. Return the patch, validation results, and any interface proposal to the coordinator.

Do not give two agents overlapping production writes or permit a subagent to broaden its own ownership. Separate review contexts can provide another perspective, but agents may share blind spots; executable evidence remains necessary.

## 10. Verification: complementary tools

### Everyday tests

Keep unit and integration tests for observable behavior. Before adding a test, name the regression it would detect. For a logic bug fix, demonstrate that the regression fails on the prior behavior for the right reason and passes with the fix, using an isolated checkout when practical. If that comparison cannot run, report the limitation.

Do not test only a stub's implementation, copy the production algorithm into the expected result, or equate line coverage with correctness. Extend relevant existing tests. Small declarative/documentation changes do not automatically need new test files.

[Proptest](https://proptest-rs.github.io/proptest/intro.html) complements ordinary examples. Generate valid states and action sequences, test invalid commands separately, and preserve minimized failures and regression seeds. Sampled property tests are not exhaustive proofs.

Candidate properties must come from the accepted specification: legal turn transitions, checked resource spending, rejection without partial mutation, save/load round trips, or deterministic replay within the documented scope. Do not invent “total biomass is conserved” if healing or other mechanics intentionally create it. Unsigned storage alone does not establish correct arithmetic or spending rules.

### Add stronger checks when justified

| Tool | Use when | Required interpretation |
| --- | --- | --- |
| [cargo-fuzz](https://rust-fuzz.github.io/book/cargo-fuzz.html) | Parsers, save/load, malformed data, command sequences | Retain crash inputs; distinguish a target bug from a faulty harness |
| [cargo-mutants](https://mutants.rs/) | Critical rule tests need scrutiny | Surviving mutations indicate a testing question, not automatically a product defect |
| [Kani](https://model-checking.github.io/kani/tutorial-loop-unwinding.html) | Small critical Rust behaviors can be checked over explicit domains | Record assumptions, domain limits, and loop-unwinding checks |
| [Verus](https://verus-lang.github.io/verus/guide/tcb.html) | A maintained formal specification is worth the cost | Review preconditions, postconditions, trusted code, and unverified boundaries |

For Kani, do not disable unwinding assertions or constrain away relevant states to get a green result. A result for one bounded domain does not establish correctness for larger states. For Verus, do not silently add assumptions, weaken the postcondition, or exclude implementation code from verification. Use the pinned version's controls for auditing trusted assumptions, such as `--no-cheating` when available.

Proofs establish specified properties under stated assumptions. They do not automatically validate the specification, rendering, packaging, external systems, or arbitrary callers that violate preconditions. Keep tests at unverified boundaries. Introduce one useful harness before adopting a large proof framework.

Keep fuzzing/sanitizer and verification toolchains isolated and reproducible. Run expensive exploration with explicit budgets. Promote useful discoveries into cheap regression tests.

## 11. Independent adversarial testing — optional experiment

This is a proposed workflow for this project. It is not a verified Omarchy CI feature, a universal best practice, or evidence that every pull request needs a second agent.

Begin with on-demand sessions for rule changes, action validation, persistence, or critical interfaces. A tester searches for counterexamples to the accepted rules: repeated actions, invalid ordering, overflow boundaries, malformed saves, or unexpected combinations of effects. It must distinguish a valid exploit from behavior the specification intentionally permits.

1. Supply the accepted rules, public API, and change description. Default to read-only production access and proposed test patches. An explicitly assigned isolated test directory may be writable for an independent task.
2. Bound the session. The agent may suggest properties, fuzz targets, action sequences, or regression tests and execute them in its permitted environment.
3. Require a reproducible report: commit, violated requirement, exact command, seed/input or action trace, expected behavior, and actual outcome. Label unreproduced suspicions as hypotheses.
4. Have the coordinator validate findings and integrate useful regressions. The tester cannot silently change rules, weaken tests, approve its own work, or merge changes.
5. Track unique confirmed bugs, false positives, runtime, model cost, and review effort. Add automatic risk-triggered PR runs or periodic broader sessions only if the pilot provides value.

For a single-player game, command-sequence property testing and fuzzing are usually the first candidates. Fault injection is useful for interrupted saves, unavailable assets, or device loss; distributed-system chaos testing becomes relevant if the application actually has distributed dependencies.

The stronger evidence is for AI helping create executable testing artifacts. Google's [OSS-Fuzz work](https://security.googleblog.com/2024/11/leveling-up-fuzzing-finding-more.html) describes model-generated fuzz targets; its [CodeMender integration](https://blog.google/security/from-finding-to-fixing-reducing-maintainer-burden-with-automated-patches/) validates proposed fixes against reproduced crashes and tests. Those results do not prove the value of a generic adversarial agent on every Rust gameplay PR.

## 12. CI, integration, and completion

### Layer CI according to risk and cost

| Trigger | Intended checks |
| --- | --- |
| Normal code PR | Formatting, compilation, Clippy, ordinary tests/doctests, bounded properties; dependency policy if configured |
| Domain/persistence/interface change | Relevant property/regression tests and existing proof/fuzz targets; optional bounded adversarial review or mutation testing |
| Renderer/platform change | Shader/pipeline validation, deterministic render checks, affected target builds, runtime checks on available appropriate backends |
| Integration/release | Validate the exact integrated commit on promised native/web targets; run required real-device/backend checks and packaging smoke tests |
| Explicitly configured periodic job | Longer fuzzing/property exploration, expensive proofs or hardware matrix, dependency checks; retain reproducible artifacts |

For a small project, a fast complete suite may be simpler than test-impact selection. Add path/dependency-based selection only when CI time justifies it; shared interfaces, manifests, build scripts, and CI changes need broader coverage. Keep a periodic or integration full run so selective testing does not permanently hide regressions.

### Commands after scaffolding

Configure explicit package and feature sets for each platform. The following is a baseline for a native-compatible workspace, **not a command to run before `Cargo.toml` exists**:

```sh
cargo fmt --all -- --check
cargo check --locked --workspace --all-targets
cargo clippy --locked --workspace --all-targets -- -D warnings
cargo nextest run --locked --workspace
cargo test --locked --workspace --doc
```

If nextest is not installed/configured, use `cargo test --locked --workspace` as the ordinary-test baseline. [Nextest does not currently run doctests](https://nexte.st/docs/running/), so keep their separate invocation when using nextest. Do not run both complete ordinary-test suites without a reason. Replace workspace-wide commands with documented package selections when some members cannot build on that host.

Add the actual WASM build command after configuring the web target, and actual proof/fuzz commands only after the corresponding harnesses exist. `--all-targets` covers Cargo target kinds for the current platform; it does not compile every operating system or GPU backend.

### Protect the evidence and integration process

1. Store logs, failing seeds/traces, screenshots/diffs, backend details, and proof assumptions as appropriate. Report passed, failed, skipped, and not-run checks distinctly.
2. Review changes to acceptance tests, golden images, specifications, proof assumptions, and CI gates explicitly. Changes are allowed when requirements change, but must not silently lower the standard used to assess the same implementation.
3. Use a fresh-context AI review for significant changes when useful, with reproducible findings preferred. Keep product behavior, ambiguous specifications, visual quality, and consequential architecture decisions reviewable by the maintainer.
4. Use least-privilege CI tokens and reproducible dependencies/actions. Do not execute untrusted PR code with secrets or on a persistent personal runner. Separate release/signing permissions from ordinary validation.
5. Integrate onto the current base and validate the resulting commit. Do not force-push, delete unrelated work, publish releases, or expand access without the necessary authorization. Respect authorization already given instead of repeatedly requesting it.

Required status checks, branch protection, path checks, and sandbox restrictions need actual configuration; this Markdown file does not enforce them. Preserve a meaningful human decision where requirements or visual quality cannot be established by the automated checks.

### Completion report

Lead with the result. State the changed behavior and relevant files, the commands actually run and their outcomes, and any remaining limitation. Do not claim support for a platform that was only cross-compiled or whose runtime tests were skipped. For documentation-only work, verify the document and links as appropriate rather than inventing a Rust test run.

## Evidence and provenance

This guide combines project decisions with documented tool capabilities. Source links were checked on **2026-11-21**; recheck version-sensitive behavior when implementing or upgrading tools.

| Source | What it supports | What it does not establish |
| --- | --- | --- |
| [Omarchy agent instructions](https://github.com/omacom/omarchy/blob/quattro/AGENTS.md) and [testing documentation](https://github.com/omacom/omarchy/blob/quattro/docs/testing.md) | A concrete example of focused tests, meaningful regressions, task guides, and runtime/visual verification | That DHH uses this Rust stack or the proposed adversarial CI schedule |
| [Evaluating AGENTS.md — ETH/LogicStar](https://www.sri.inf.ethz.ch/publications/gloaguen2026agentsmd) | In its tested settings, repository context files added cost without improved task success | A universal optimal instruction length or a finding that all instructions are useless |
| [On the Impact of AGENTS.md Files](https://arxiv.org/abs/2601.20404) | A different study reported efficiency improvements with comparable completion behavior | A controlled ranking of all instruction formats, architectures, or agent personas |
| Google OSS-Fuzz/CodeMender sources in Section 11 | Concrete AI-assisted testing and validated repair workflows | Proof that agent opinions replace tests, proofs, or human judgment |

Do not present the suggested module structure, agent roles, verification mix, or CI cadence as a scientifically proven optimum. Evaluate them against this project's change success, regressions, feedback time, context/model cost, and maintenance burden.
