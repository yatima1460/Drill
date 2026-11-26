#!/bin/bash
set -e
cd "$(dirname "$0")"
. scripts/launcher-env.sh
cargo test --locked -p drill --bin drill
echo "Opening a real Drill window; please do not use the keyboard or mouse until the tests finish."
cargo test --locked -p drill --features ui-test-driver --test native_ui -- --ignored --nocapture --test-threads=1
read -r -p "UI tests finished. Press Enter to close this window..."
