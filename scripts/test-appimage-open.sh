#!/usr/bin/env bash
# Run in a fresh X11/D-Bus session with Xed, Nemo and an empty test home.
set -euo pipefail
image=${1:?Pass the packaged AppImage}
driver=${2:-"$(dirname "$0")/../tests/native_ui/linux.py"}
export XDG_CURRENT_DESKTOP=X-Cinnamon XDG_SESSION_TYPE=x11 GDK_BACKEND=x11 NO_AT_BRIDGE=0 LIBGL_ALWAYS_SOFTWARE=1
root="$HOME/Documents"
mkdir -p "$HOME/.config" "$root/Drill folder sample"
printf 'Sample\n' > "$root/Drill text sample.txt"
xdg-mime default org.x.editor.desktop text/plain
xdg-mime default nemo.desktop inode/directory
[[ $(xdg-mime query default text/plain) == org.x.editor.desktop ]]
[[ $(xdg-mime query default inode/directory) == nemo.desktop ]]

openbox > /tmp/drill-openbox.log 2>&1 &
wm_pid=$!
APPIMAGE_EXTRACT_AND_RUN=1 "$image" --root "$root" > /tmp/drill-appimage.log 2>&1 &
app_pid=$!
cleanup() {
    local status=$?
    kill "$app_pid" "$wm_pid" 2>/dev/null || true
    if (( status != 0 )); then
        wmctrl -lx || true
        cat /tmp/drill-appimage.log >&2
    fi
}
trap cleanup EXIT

open_result() {
    local query=$1 class=$2 title deadline
    python3 "$driver" open "$query"
    deadline=$((SECONDS + 30))
    while (( SECONDS < deadline )); do
        title=$(wmctrl -lx | awk -v app="$class" -v file="$query" '
            { split(tolower($3), cls, ".") }
            (cls[1] == app || cls[2] == app) && index($0, file) { print }
        ')
        if [[ -n "$title" ]]; then
            printf 'Opened in %s: %s\n' "$class" "$title"
            return 0
        fi
        sleep 0.2
    done
    echo "Expected $class to show $query" >&2
    return 1
}
open_result 'Drill text sample.txt' xed
open_result 'Drill folder sample' nemo
