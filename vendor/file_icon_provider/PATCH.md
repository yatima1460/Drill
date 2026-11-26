# Local file_icon_provider patch

The library sources are from the MIT-licensed file_icon_provider 1.0.2 crate
by Iohann Rabeson, published from [upstream commit b3723cf](https://github.com/IohannRabeson/file_icon_provider/tree/b3723cfac725b09c3faf1cf3a370aab5a7013d47).
The crates.io archive has SHA-256 checksum `4ff9f725b347b91d04340444fcbce0770886e4a6513e5f8e9e73a9e344efe73b`.

The Linux dependency on the GTK3 bindings is updated to `gtk` 0.19, which
uses the patched GLib bindings. The icon tests use Cargo's manifest directory
to locate their sample file. Check that updates to the provider retain the
fix for [GHSA-wrw7-89jp-8q8g](https://github.com/advisories/GHSA-wrw7-89jp-8q8g).

The macOS manifest enables the framework bindings used to look up file types
and draw native icons. Keep this feature selection when updating the provider.
