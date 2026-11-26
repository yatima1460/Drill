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

Pull requests changing Rust code or verification inputs run these checks on Linux. The separate release workflow continues to exercise the native window, Windows build under Wine, and the Linux rebuild of the shipped Wasm asset.

## What Kani checks

The independent proof workspace imports the same modules compiled by the application and guest. All harnesses run with Kani's default memory, overflow, assertion reachability and unwinding checks.

| Contract | Inputs and property |
| --- | --- |
| Search worker application filters | For every Unix extension byte sequence of length 0 through 4, and each supported file kind (regular file, directory or other), the unrestricted filter accepts it. The application filters accept only the appropriate kind and the complete ASCII case-insensitive suffix `app` or `exe`. This exercises invalid UTF-8 bytes too. The harness unwinds loops up to 6. |
| Desktop result order and selection | From every valid exact-prefix boundary and optional selection in a list of 0–3 distinguishable rows, insert 0–2 new exact hits. The original exact prefix, new exact hits and old partial hits retain their order. The selected row keeps its identity and the prefix length stays accurate. The harness unwinds loops up to 10. |
| PE resource coordinates in the Wasm icon guest | Every 64-bit offset, 32-bit size and 32-bit input length. The resource range exists precisely when its mathematical endpoint fits in the input. The endpoints and byte count agree with widened arithmetic, including empty ranges at EOF. |

The filter proof begins after the filesystem supplies the entry type and pathname extension. The UI proof begins after hits have been classified. The resource proof covers checked range arithmetic. Walking directories, cancellation and scheduling, matching text, platform-specific pathname encodings and OS APIs, rendering, the host/guest pointer ABI and third-party parsers remain outside those proofs. Explicit unit, fixture and platform tests exercise these boundaries.

## Mutation campaigns

`make test-mutants` runs all candidates in the search file-filter and guest resource-range modules, plus desktop exact-hit insertion and executable icon routing. Each run starts with unmutated tests and fails for a surviving mutation, timeout or failed baseline. The smoke campaign also requires at least one test-detected mutation per package. A candidate rejected by the Rust compiler counts as unviable.

For a broader run, choose one of these scopes. Each command uses the native platform's tests. Set `MUTATION_SHARD=0/32` to run the first of 32 disjoint shards at a fixed revision, then use `1/32` through `31/32` for the others. The **Rust verification** workflow dispatch accepts the same scope and shard and offers Linux, macOS and Windows runners.

```sh
scripts/test-mutants.sh core full
MUTATION_SHARD=0/32 scripts/test-mutants.sh desktop full
scripts/test-mutants.sh guest full
```

| Scope | Candidates and test boundary |
| --- | --- |
| `core` | `drill-core` query parsing and matching, traversal, filters, ranking and worker control. Runs its tests against temporary filesystem fixtures. |
| `desktop` | Desktop state, search-mode adapter, headless egui logic, executable snapshot/Wasmi host and applicable native adapters. Linux includes the application catalog. macOS includes permissions and native menus. Windows includes its native menu and shell code. The ordinary suite leaves interactive OS-input tests to the dedicated window workflow. |
| `guest` | The standalone `tools/exe-icon-wasm` crate. Native tests feed the actual extraction function PE32 and PE32+ fixtures, exercise truncated input, and check resource-range boundaries. The separate Linux Wasm rebuild and host tests cover the shipped guest. |

The full campaigns preserve all candidate outcomes, including surviving changes in OS effects or branches inactive on the selected target. Use the appropriate native runner when investigating them. A survivor can expose a missing assertion or a behaviorally equivalent change. Inspect `target/mutations/<scope>/mutants.out/` for test logs, diffs, `missed.txt`, `timeout.txt`, and `outcomes.json`. CI uploads these reports even on failures. Each mutation gets a 90-second test budget and a 15-minute build budget. Each CI mutation job has a 90-minute limit; choose smaller shards for desktop work.

The vendored eframe and file-icon-provider dependency patches are exercised by the application builds and platform checks. Third-party dependencies, the website, packaging and signing scripts are outside the Rust mutation inventory.
