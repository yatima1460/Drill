#!/usr/bin/env bash
set -euo pipefail
# Xvfb supplies a display; Openbox supplies focus/activation semantics.
openbox >/dev/null 2>&1 &
wm_pid=$!
trap 'kill "$wm_pid" 2>/dev/null || true' EXIT
cargo test --locked -p drill --features ui-test-driver --test native_ui -- --ignored --nocapture --test-threads=1
