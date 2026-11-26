#!/usr/bin/env bash
# Bundle the committed checkout and all Cargo-locked sources needed offline.
set -euo pipefail

repo=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
revision=$(git -C "$repo" rev-parse HEAD)
name="Drill-source-$revision"
destination=${1:-"$repo/dist"}
mkdir -p -- "$destination"
destination=$(cd -- "$destination" && pwd -P)
stage=$(mktemp -d)
archive=""
trap 'rm -rf -- "$stage"; if [[ -n "$archive" ]]; then rm -f -- "$archive"; fi' EXIT
mkdir "$stage/$name"
git -C "$repo" archive "$revision" | tar -xf - -C "$stage/$name"

(
  cd "$stage/$name"
  cargo vendor --locked --versioned-dirs \
    --sync tools/exe-icon-wasm/Cargo.toml \
    --sync tools/appimage-icon-wasm/Cargo.toml \
    --sync verification/Cargo.toml cargo-sources > "$stage/source-config.toml"
  mkdir -p .cargo
  cat "$stage/source-config.toml" >> .cargo/config.toml
)

archive=$(mktemp "$destination/.Drill-source-XXXXXXXX")
tar -cf - -C "$stage" "$name" | gzip -1 > "$archive"
chmod 644 "$archive"
mv -f -- "$archive" "$destination/$name.tar.gz"
archive=""
printf '%s\n' "$destination/$name.tar.gz"
