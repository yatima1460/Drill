#!/usr/bin/env bash
set -euo pipefail

# A disposable prefix and virtual display keep the smoke test away from real user sessions.
export WINEPREFIX
WINEPREFIX=$(mktemp -d)
export WINEARCH=win64 WINEDEBUG=-all WINEDLLOVERRIDES='mscoree,mshtml=' LIBGL_ALWAYS_SOFTWARE=1
log_file="$WINEPREFIX/drill-test.log"
openbox >/dev/null 2>&1 &
wm_pid=$!
app_pid=''
cleanup() {
    if [[ -n "$app_pid" ]]; then kill "$app_pid" 2>/dev/null || true; fi
    wineserver -k 2>/dev/null || true
    timeout 10s wineserver -w 2>/dev/null || true
    kill "$wm_pid" 2>/dev/null || true
    rm -rf "$WINEPREFIX"
}
trap cleanup EXIT

make start_wine >"$log_file" 2>&1 &
app_pid=$!
if ! window_id=$(timeout 120s xdotool search --sync --onlyvisible --name '^Drill'); then
    cat "$log_file" >&2
    echo 'Drill did not open a visible window under Wine.' >&2
    exit 1
fi
window_id=${window_id%%$'\n'*}
xdotool windowactivate --sync "$window_id" key --clearmodifiers Escape
for _ in {1..30}; do
    if ! kill -0 "$app_pid" 2>/dev/null; then
        wait "$app_pid"
        app_pid=''
        cleanup
        trap - EXIT
        exit 0
    fi
    sleep 1
done
cat "$log_file" >&2
echo 'Drill did not exit after Escape under Wine.' >&2
exit 1
