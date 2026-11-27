# Mutation testing and bounded verification

## Reproduce the checks

Use the repository Rust toolchain and run from the repository root. Kani supports Linux and macOS. Its setup installs a separate matching nightly compiler and CBMC. The desktop mutation suite needs the same native libraries as the development build on that host.

```sh
. verification/tools.env
cargo install --locked --version "$KANI_VERSION" kani-verifier
cargo kani setup
cargo install --locked --version "$MUTANTS_VERSION" cargo-mutants
make prove
make test-mutants
```

Kani runs on pull requests that change the proof workspace, its imported modules or its build inputs. Mutation checks cover changes to the packages they exercise. The platform workflow tests shared application changes on Linux, macOS and Windows under Wine. A change specific to one platform runs its corresponding build. After an application change merges to main, the release workflow rebuilds all three platforms together.

To check the packaged AppImage icon locally, build the Linux package or set `DRILL_PACKAGED_APPIMAGE` to a built AppImage. Run the check with its reference decoder enabled.

```sh
cargo test --locked -p drill --features verify-packaged-appimage --test packaged_appimage packaged_appimage_contains_drill_icon -- --ignored --exact
```

This check uses the original artwork and an independent PNG decoder as its reference.

## Duplicate code

Source changes run jscpd 5.4.3 on the full checkout. Each release also requires this check on its integrated main commit. Any reported clone fails the job and blocks release signing. To reproduce it, build the vendored detector and run it from the repository root.

```sh
cargo build --locked --release --manifest-path vendor/jscpd/rust/Cargo.toml -p jscpd --bin jscpd --target-dir target/jscpd
target/jscpd/release/jscpd .
```

CI verifies the [vendored source](../vendor/jscpd) against its pinned upstream Git tree. On a cache miss it builds the executable using Drill's pinned Rust toolchain and jscpd's own lockfile. Only pushes to the upstream main branch save the executable and its checksum. CI verifies the checksum and version before each scan. Pull requests limited to excluded files such as binary assets skip the duplicate scan.

The detector reports repeated blocks of at least 50 tokens spanning at least five lines, including repeats within one file. It checks tests, shell launchers, workflows, website code and the other supported formats. The configuration excludes vendored dependencies, Cargo lockfiles, the generated website lint dependency lockfile, the word list and the three Potrace-generated Drill logos. jscpd respects Git ignore files for local build output.

## What Kani checks

The independent proof workspace imports the same modules compiled by the application and guest. All harnesses run with Kani's default memory, overflow, assertion reachability and unwinding checks.

| Contract | Inputs and property |
| --- | --- |
| Search worker application filters | For every Unix extension byte sequence of length 0 through 4, and each supported file kind (regular file, directory or other), the unrestricted filter accepts it. The application filters accept only the appropriate kind and the complete ASCII case-insensitive suffix `app` or `exe`. This exercises invalid UTF-8 bytes too. The harness unwinds loops up to 6. |
| Desktop result order and selection | For every representable row count, exact-prefix boundary, batch size and optional valid selection on the 64-bit proof target, the new exact interval starts at the old prefix and has precisely the batch length. The selected row stays outside the new interval and maps back to its original position. The preconditions require a valid old prefix and a representable new total. |
| PE resource coordinates in the Wasm icon guest | Every 64-bit offset, 32-bit size and 32-bit input length. The resource range exists precisely when its mathematical endpoint fits in the input. The endpoints and byte count agree with widened arithmetic, including empty ranges at EOF. |
| AppImage SquashFS read offsets | For every 64-bit archive start, relative offset, read length and file length, translation succeeds exactly when the entire read lies inside the selected file. Zero-length reads may start at EOF. The absolute offset agrees with 128-bit arithmetic. |

The filter proof begins after the filesystem supplies the entry type and pathname extension. The UI proof begins after hits have been classified and covers the coordinates passed to `Vec::splice`. Headless UI tests check the resulting row contents and selection across successive batches. The resource proof covers checked range arithmetic. Walking directories, cancellation and scheduling, matching text, platform-specific pathname encodings and OS APIs, rendering, the host/guest pointer ABI and third-party parsers remain outside those proofs. Explicit unit, fixture and platform tests exercise these boundaries.

## Mutation campaigns

`make test-mutants` runs all candidates in query stem classification, the search file-filter and both guests’ read-boundary modules, plus desktop exact-hit insertion and executable icon routing. Each run starts with unmutated tests and fails for a surviving mutation, timeout or failed baseline. The smoke campaign also requires at least one test-detected mutation per scope. A candidate rejected by the Rust compiler counts as unviable.

For a broader run, choose one of these scopes. Each command uses the native platform's tests. Set `MUTATION_SHARD=0/32` to run the first of 32 disjoint shards at a fixed revision, then use `1/32` through `31/32` for the others. The **Rust verification** workflow dispatch accepts the same scope and shard and offers Linux, macOS and Windows runners.

```sh
scripts/test-mutants.sh query full
scripts/test-mutants.sh core full
MUTATION_SHARD=0/32 scripts/test-mutants.sh desktop full
scripts/test-mutants.sh guest full
scripts/test-mutants.sh appimage full
```

| Scope | Candidates and test boundary |
| --- | --- |
| `query` | `drill-query` parsing, normalization, matching, stem classification and Windows lookup rules. Its tests run without filesystem fixtures or a window. |
| `core` | `drill-core` traversal, filters, ranking and worker control. Runs its tests against temporary filesystem fixtures. |
| `desktop` | The shared desktop model in `drill-desktop` and its Rust tests. Full campaigns also exercise the Wasm icon hosts. Native UI workflows drive the platform controls. |
| `guest` | The standalone `tools/exe-icon-wasm` crate. Native tests feed the actual extraction function PE32 and PE32+ fixtures, exercise truncated input, and check resource-range boundaries. The separate Linux Wasm rebuild and host tests cover the shipped guest. |
| `appimage` | The `tools/appimage-icon-wasm` crate. Native tests exercise the same read-only parser and image decoder on ISO/Rock Ridge and SquashFS fixtures, including links, truncated inputs and a cycle. Desktop tests exercise the shipped Wasm ABI. Linux CI compares the icon from the packaged application with its source artwork. |

The full campaigns preserve all candidate outcomes, including surviving changes in OS effects or branches inactive on the selected target. Use the appropriate native runner when investigating them. A survivor can expose a missing assertion or a behaviorally equivalent change. Inspect `target/mutations/<scope>/mutants.out/` for test logs, diffs, `missed.txt`, `timeout.txt`, and `outcomes.json`. CI uploads these reports even on failures. Each mutation gets a 90-second test budget and a 15-minute build budget. Each CI mutation job has a 90-minute limit; choose smaller shards for desktop work.

The native SDK adapter crates and their C and Objective-C code are exercised through their consumers and platform checks. This includes the Windows filename lookup in the startup tests, the Windows icon fixture on a native runner, the Linux appearance observer on a private D-Bus session, and the Swift interaction suite on a private pasteboard. The mutation campaigns target the Rust code in the packages named above. Third-party dependencies, the website, packaging and signing scripts are outside the Rust mutation inventory.
