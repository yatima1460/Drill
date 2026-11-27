# Rust migration

Drill shares its Rust search engine across the SwiftUI and AppKit app on macOS and two native frontends built with Win32 on Windows and GTK 3 on Linux. The former Python implementation remains in Git history.

On macOS 13 or later, install Rust through rustup and the Xcode Command Line Tools. Run `make start` or open `Start Drill.command`. On Windows and Linux, run `cargo run --release --locked`. The first build may download dependencies.

Desktop releases use optimization level 3, Cargo's default parallel code
generation, and explicitly disable link-time optimization. See the
[measured release-profile tradeoff](../AGENTS.md#desktop-release-profile).
The embedded Wasm icon decoders use separate size-focused release profiles.

Linux builds use `pkg-config`, a C compiler and an archiver to compile the small
GTK 3 and GIO adapter against the system development files. For cross-compilation
set `CC` and `AR` for the target when the default tool names do not match.
Use target-qualified `CFLAGS` to pass Clang's `--target` or a compiler sysroot.
Quote paths that contain spaces.
Set `PKG_CONFIG` to the target's executable or set `PKG_CONFIG_SYSROOT_DIR`
with the target's `PKG_CONFIG_LIBDIR`.

For macOS Swift app timings, use the [native build benchmark](swift-ui.md#measuring-compilation), which includes the Swift compiler, bundle assembly and local signing. To compare clean Linux builds of the GTK app, give the benchmark a fresh output directory and
the paths to clean checkouts. Fetch their locked dependencies first. Pass the
same C compiler driver that Rust normally uses to also measure the final link.

```sh
python3 scripts/bench-clean-build.py --runs 6 --jobs 12 --linker cc \
  --timings-dir /tmp/drill-cargo-timings /path/to/baseline /path/to/candidate
```

The JSON output records full build time, time inside the final linker driver,
and counts of compiled packages and units. Each run uses empty build directories
and executes the linked binary. Cargo's HTML reports show overlapping work per
unit. Build scripts and procedural macros can cost time before the final link.

The Rust search code runs off the UI thread, scans the existing platform root lists without indexing, and skips directory symlinks. Plain and `fuzzy:` searches ignore case and accents. Plain search requires every word to occur in the name. Results can be opened or revealed from the context menu. Search → Stop cancels an active or starting search and retains the results already shown. macOS and Windows use native application menus; Linux shows the menu inside the window.

Drill compiles filename globs into regular expressions using the Wax 0.7 pattern syntax. Wildcard searches match the whole name and ignore case and accents. A bare asterisk selects wildcard search, so `*.md`, `myfile*`, `*myfile` and `*myfile*` find a suffix, prefix, ending and substring respectively. Use `glob:` for patterns with single-character wildcards or character classes, such as `glob:page[0-9]?.pdf`. Escape a literal asterisk with a backslash, as in `glob:report\*.txt`. Other punctuation in plain searches stays literal.

Use `regex:` to search the original name with a Rust regular expression. Regex searches ignore case by default and preserve accents. Anchors select the beginning or end of the name, as in `regex:^IMG_[0-9]{4}\.jpg$`. Use `(?-i)` within a regex for case-sensitive matching. Drill shows an inline error for an invalid or empty pattern. Patterns can use up to 4,096 bytes, and glob groups can nest up to eight levels. Patterns match names in Files mode and the existing application search fields in Apps mode.

Use the **Files / Apps** dropdown beside the search field to change scope and keep the current query. Files is the default. An empty Apps search lists applications. On macOS, Apps finds application bundles and treats each bundle as one result. On Windows, Apps finds executable files. A plain search for a full executable name, such as `notepad.exe`, looks up that filename directly in System32, the Windows directory and the current user’s WindowsApps alias directory. These optional lookups run alongside drive discovery and the full search in both Files and Apps. Ordinary text, glob and regex searches use the normal walk. On Linux, Apps searches the desktop menu by localized app name, launcher ID, filename or keywords. Enter or double-click launches the selected app. **Reveal launcher file** opens its containing folder. Files mode also searches the XDG applications directories for the original `.desktop` files.

Among the results shown, exact filenames appear first by default. When more than 10,000 matches are available, click **Continue searching** to see the next 10,000 from the same scan. Any exact filenames in the new page move to the top when using the default ordering.

Click a result column header to sort; drag the divider between headers to resize the adjacent columns. Column widths are retained for the current session.

On macOS, Settings → Permissions lets the user choose folders using the system picker and open the Files and Folders or Full Disk Access settings. Chosen folders are included in searches for the current session. A folder check only reports whether Drill could list that folder at the time; macOS manages access and a successful check does not prove Full Disk Access. The released app is not sandboxed. If the app is started through a terminal, macOS may attribute access to that terminal instead of the packaged app.

`make start_wine` builds the current checkout for `x86_64-pc-windows-gnu` and runs it with Wine. It requires Wine, the `x86_64-w64-mingw32-gcc` MinGW-w64 cross-linker, and the Rust target (`rustup target add x86_64-pc-windows-gnu`). Set `WINE` or `WINDOWS_LINKER` when either executable is not on `PATH`. On Apple silicon, an installed Wine distribution must also support running x86-64 Windows programs; this is separate from the native macOS build. CI exercises the launcher in a disposable Wine prefix and virtual Linux display; that does not establish Wine behavior on macOS.

Under Settings → Interface, choose Auto to follow system appearance changes, or select Light or Dark. Drill applies the choice immediately and remembers it across launches. Auto is the default.

Windows uses the Shell icon registered for a file’s extension and the standard Windows folder icon on writable drives, network shares and other volumes that are ineligible for per-item lookups. Drill requests a particular file or folder’s cached Shell icon only for eligible paths on a verified read-only local fixed volume. If the cache has no icon for that item, Drill keeps the file-type or folder icon.

**Settings → Interface** has independent options for embedded EXE and AppImage icons. Both default to enabled. For EXE files, Drill reads a size-limited snapshot and decodes it in a bundled WebAssembly module with no host imports and fixed memory and execution budgets. When the setting is disabled or decoding fails, Drill uses the system file-type icon or a generic file icon. On macOS the icon worker avoids materializing cloud-only files. Linux CI rebuilds the decoder from `tools/exe-icon-wasm` and compares it with the shipped module.

For AppImages, a background worker reads the `.DirIcon` from Type 1 ISO 9660/Rock Ridge images and Type 2 images with an appended SquashFS filesystem. Icon links resolve inside the archive. PNGs up to 1024 × 1024 and self-contained vector SVGs are drawn at 32 × 32. Missing, unsupported or unreadable icons use the AppImage system file-type icon or a generic file glyph. The worker never executes or mounts the AppImage. Its dedicated Wasm guest can only request bounded reads of the already opened file, up to 8 MiB in total, with 64 MiB of guest memory and a fuel limit. Linux CI rebuilds `tools/appimage-icon-wasm` and compares the icon in the packaged Drill AppImage with the source artwork.

Development checks: `cargo fmt --check`, `cargo check --locked`, `cargo clippy --locked --all-targets -- -D warnings`, and `cargo test --locked`.

CI builds a macOS DMG, Windows x86-64 ZIP, and Linux Debian, Arch, and AppImage packages. Windows is cross-compiled on Linux; the archive is inspected there but still requires a native Windows runtime check. Local builds and PR artifacts contain a preview DMG. GitHub releases use the signed and notarized DMG described below. The AppImage relies on compatible system graphics libraries. After all platform checks pass, a push to `main` that matches the merge commit of a PR into `yatima1460/Drill:main` can request a production deployment. Direct pushes, tags, pull requests and manual runs cannot publish. The repository owner approves the deployment and can retry a failed release.

Open the macOS disk image and drag Drill onto the Applications folder at the right. To build the preview locally, run `make package-macos`. Packaging installs the two hash-pinned Finder metadata wheels into a build-local Python 3 virtual environment. It creates an HFS+ image with fixed icon positions and an arrow background, then mounts the compressed preview to check its layout and executable. The production job signs the app in the verified staged image before compressing and signing the DMG.

### macOS production credentials

The GitHub Actions environment `prod` allows only the branch `main` and requires approval from `yatima1460`. Before approving, verify the workflow, signing scripts and commit displayed for the deployment. Keep these credentials exclusively in that environment.

| Environment secret | Contents |
| --- | --- |
| `MACOS_CERTIFICATE_P12_BASE64` | Base64 of the password-protected PKCS#12 export for Developer ID Application: Pandaware LLC (ZYRW8ZPM2V), including its private key |
| `MACOS_CERTIFICATE_PASSWORD` | The PKCS#12 export password |
| `APPLE_NOTARY_KEY_P8` | The text of the dedicated App Store Connect team API private key, including its PEM header and footer |
| `APPLE_NOTARY_KEY_ID` | The API key ID |
| `APPLE_NOTARY_ISSUER_ID` | The Pandaware team API issuer ID |

The signing job retrieves the staged disk image by artifact ID and verifies its SHA-256 digest. It signs `software.drill` with Hardened Runtime and a secure timestamp, signs the DMG, submits it to Apple and staples the accepted ticket. The publisher retrieves the validated DMG by its artifact ID. Missing credentials or failed verification block publication.

The query and search core packages forbid unsafe Rust. Run `cargo test --locked -p drill-query` for pure matching and normalization tests, or `make test-core` to include traversal and result delivery. The Windows and Linux model keeps original filesystem paths alongside display strings. Its C interface bounds the lifetime of memory borrowed by Win32 and GTK. The Linux GTK and GIO adapter lives in `crates/drill-gtk`. The Wasm guests use pointers at their host boundaries. The EXE guest has no host imports. The AppImage guest imports a read-only function scoped to the selected file. CI checks for undocumented unsafe blocks in the workspace targets it builds. Focused tests cover matching, priority, overlapping roots, completion and cancellation with a full result queue. Run `make prove` and `make test-mutants` for additional checks. See [verification domains, commands and limits](verification.md).

On macOS, `Run Core Tests.command` runs the query and traversal package tests. `Run UI Tests.command` runs the Swift interaction suite using AppKit windows and input events scoped to the test process. Linux CI drives the GTK window on a virtual X display.
