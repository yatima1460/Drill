#!/usr/bin/env bash
set -euo pipefail
# The caller supplies a private X11 display. Give its AT-SPI registry a
# private session bus as well, including when run inside a desktop session.
if [[ ${1-} != --session ]]; then
    exec dbus-run-session -- "$0" --session
fi
export GDK_BACKEND=x11 NO_AT_BRIDGE=0
openbox >/dev/null 2>&1 &
wm_pid=$!
trap 'kill "$wm_pid" 2>/dev/null || true' EXIT
"${CARGO:-cargo}" test --locked -p drill --test native_ui -- --ignored --nocapture --test-threads=1
