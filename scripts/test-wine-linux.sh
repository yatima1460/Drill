#!/usr/bin/env bash
set -euo pipefail

# All physical input from the driver stays inside this private X desktop.
if [[ ${1-} != '--inside-private-xvfb' ]]; then
    exec xvfb-run -a "$0" --inside-private-xvfb "$@"
fi
shift
if [[ $# != 0 && $# != 2 ]]; then
    echo "Usage: $0 [driver.exe Drill.exe]" >&2
    exit 2
fi

export WINEPREFIX
WINEPREFIX=$(mktemp -d)
export WINEARCH=win64 WINEDEBUG=-all WINEDLLOVERRIDES='mscoree,mshtml='
openbox >/dev/null 2>&1 &
wm_pid=$!
cleanup() {
    wineserver -k 2>/dev/null || true
    timeout 10s wineserver -w 2>/dev/null || true
    kill "$wm_pid" 2>/dev/null || true
    rm -rf "$WINEPREFIX"
}
trap cleanup EXIT

if [[ $# == 2 ]]; then
    driver=$1
    application=$2
else
    linker=${WINDOWS_LINKER:-x86_64-w64-mingw32-gcc}
    target_dir=${CARGO_TARGET_DIR:-target}
    CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER="$linker" RUSTFLAGS="${RUSTFLAGS-} -C target-feature=+crt-static" \
        "${CARGO:-cargo}" build --release --locked -p drill --bin drill --target x86_64-pc-windows-gnu --target-dir "$target_dir"
    application="$target_dir/x86_64-pc-windows-gnu/release/drill.exe"
    driver="$WINEPREFIX/drill-native-window.exe"
    "$linker" -std=c11 -municode -Wall -Wextra -Werror crates/drill-windows/tests/native_window.c \
        -o "$driver" -lgdi32 -ladvapi32 -loleacc -loleaut32 -lole32 -luuid
fi
windows_app=$(timeout 120s winepath -w "$(realpath -- "$application")")
# MSAA row annotations are checked by this driver on native Windows.
timeout 120s "${WINE:-wine}" "$driver" "$windows_app" --wine
