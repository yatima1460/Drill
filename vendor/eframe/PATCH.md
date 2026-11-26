# Local eframe patch

This directory contains eframe 0.31.1 from crates.io, corresponding to egui
commit `1669e52a7ccfc3489c1b0999b9ed48894a0b3887`. It is distributed under
the MIT or Apache-2.0 license; both license texts are included here.

`src/native/glow_integration.rs` adds a Windows desktop OpenGL compatibility
context attempt after both the normal desktop and OpenGL ES context attempts
fail. Wine on macOS can reject the first two while supporting the compatibility
context. This follows the approach later adopted upstream in
<https://github.com/emilk/egui/pull/8655>. Remove the patch when updating to an
eframe version that provides the fallback and verify the Wine launcher again.

On macOS, the Glow integration refreshes the cached system appearance when an
app removes a window theme override. AppKit can suppress change notifications
while a window is forced light or dark. Refreshing on return to Auto covers a
desktop appearance change that happened during the override.

The Linux integration uses egui-winit's browser launcher for the two HTTPS
help links, including its handling of `$BROWSER` and desktop fallbacks. Drill
uses native launchers on macOS and Windows. All three retain clipboard support.

Desktop persistence uses the standard library to locate the Unix home directory.
The optional `document-features` feature generates the feature list for docs.rs.
