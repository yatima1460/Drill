#!/usr/bin/env bash
set -euo pipefail

# Preserve ordinary stdout for CLI queries. The GUI launcher gives its icon
# worker a pair of private pipes to a reader running on the Unix host.
for arg in "$@"; do
    if [[ $arg == --version ]]; then
        exec "${WINE:-wine}" "$@"
    fi
done
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
unset RUSTFLAGS CARGO_ENCODED_RUSTFLAGS CARGO_BUILD_TARGET
exec "${CARGO:-cargo}" run --quiet --locked --release --manifest-path "$root/Cargo.toml" \
    -p drill-icons --features wine-bundle-host --bin drill-wine -- "${WINE:-wine}" "$@"
