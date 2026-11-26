# Local file_icon_provider patch

The library sources are from the MIT-licensed file_icon_provider 1.0.2 crate
by Iohann Rabeson, published from [upstream commit b3723cf](https://github.com/IohannRabeson/file_icon_provider/tree/b3723cfac725b09c3faf1cf3a370aab5a7013d47).
The crates.io archive has SHA-256 checksum `4ff9f725b347b91d04340444fcbce0770886e4a6513e5f8e9e73a9e344efe73b`.

The Linux dependency on the GTK3 bindings is updated to `gtk` 0.19, which
uses the patched GLib bindings. The manifest includes the library and its unit
test dependency. Switch back to the published provider when it adopts GTK3
bindings that resolve [GHSA-wrw7-89jp-8q8g](https://github.com/advisories/GHSA-wrw7-89jp-8q8g).
