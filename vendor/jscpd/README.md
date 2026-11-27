# jscpd source for CI

Drill's duplicate-code check builds the Rust workspace in this directory. It is a separate Cargo workspace used only by CI. The desktop application has no dependency on it.

The `rust/` directory is the complete upstream workspace from [jscpd v5.4.3](https://github.com/kucherenko/jscpd/tree/b82d84186389590fed0813d005391f3b8147dcfa/rust). Its Git tree is `160643ef0d0d0379705ea730a92989269d68a5b4`. The upstream MIT license is in [LICENSE](LICENSE). Bundled resources retain their upstream notices.

For an update, import the release's complete `rust/` directory and root license, compare the committed subtree with the upstream Git tree, and update the tree and version checks in `.github/ci/prepare-jscpd.sh`. Keep the workspace's lockfile and local patches with the source. A cold build still needs the registry sources specified in that lockfile. See the [build and scan commands](../../docs/verification.md#duplicate-code).
