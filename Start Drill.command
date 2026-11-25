#!/bin/bash
set -e
cd "$(dirname "$0")"
if [ -f "$HOME/.cargo/env" ]; then
    # shellcheck source=/dev/null
    . "$HOME/.cargo/env"
fi
if ! command -v cargo >/dev/null 2>&1; then
    echo "Rust and Cargo are required. Install them from https://rustup.rs/ and try again."
    read -r -p "Press Enter to close this window..."
    exit 1
fi
cargo run --release
