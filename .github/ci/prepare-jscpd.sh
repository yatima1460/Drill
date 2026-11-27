#!/usr/bin/env bash
set -euo pipefail

cache_dir=$1
cache_hit=$2
cd -- "$(git rev-parse --show-toplevel)"
source_tree=$(git rev-parse HEAD:vendor/jscpd/rust)
if [[ $source_tree != 160643ef0d0d0379705ea730a92989269d68a5b4 ]]; then
    echo 'Vendored jscpd source differs from the pinned v5.4.3 tree' >&2
    exit 1
fi

if [[ $cache_hit != true ]]; then
    target_dir="$RUNNER_TEMP/jscpd-target"
    cargo build --manifest-path vendor/jscpd/rust/Cargo.toml --locked --release \
        -p jscpd --bin jscpd --target-dir "$target_dir"
    mkdir -p -- "$cache_dir"
    install -m 755 "$target_dir/release/jscpd" "$cache_dir/jscpd"
    (cd -- "$cache_dir" && sha256sum jscpd > jscpd.sha256)
fi

cd -- "$cache_dir"
# Hash this exact executable regardless of the contents of the checksum file.
actual=$(sha256sum jscpd)
expected=$(cat jscpd.sha256)
[[ $actual == "$expected" ]] || {
    echo 'Cached jscpd checksum mismatch' >&2
    exit 1
}
[[ $(./jscpd --version) == 'jscpd 5.4.3' ]]
