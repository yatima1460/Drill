#!/usr/bin/env bash
# Run in a fresh X11/D-Bus session with Xed, Nemo and an empty test home.
set -euo pipefail
image=${1:?Pass the packaged AppImage}
export XDG_CURRENT_DESKTOP=X-Cinnamon XDG_SESSION_TYPE=x11 LIBGL_ALWAYS_SOFTWARE=1
mkdir -p "$HOME/.config" "$HOME/Documents" "$HOME/Drill folder sample"
printf 'Sample\n' > "$HOME/Documents/Drill text sample.txt"
xdg-mime default org.x.editor.desktop text/plain
xdg-mime default nemo.desktop inode/directory
[[ $(xdg-mime query default text/plain) == org.x.editor.desktop ]]
[[ $(xdg-mime query default inode/directory) == nemo.desktop ]]

openbox > /tmp/drill-openbox.log 2>&1 &
wm_pid=$!
APPIMAGE_EXTRACT_AND_RUN=1 "$image" > /tmp/drill-appimage.log 2>&1 &
app_pid=$!
cleanup() {
    local status=$?
    kill "$app_pid" "$wm_pid" 2>/dev/null || true
    if (( status != 0 )); then
        xdotool search --onlyvisible --name '.*' getwindowname %@ || true
        cat /tmp/drill-appimage.log >&2
    fi
}
trap cleanup EXIT

drill=$(timeout 30 xdotool search --sync --onlyvisible --name '^Drill$')
open_result() {
    local query=$1 class=$2 title
    timeout 5 xdotool windowactivate --sync "$drill"
    xdotool mousemove --window "$drill" 90 47 click 1 key ctrl+a BackSpace
    timeout 10 xdotool search --sync --onlyvisible --name '^Drill$' >/dev/null
    xdotool type --clearmodifiers "$query"
    timeout 45 xdotool search --sync --onlyvisible --name '^Drill - 1 items found - done$' >/dev/null
    xdotool mousemove --window "$drill" 115 118 click --repeat 2 --delay 90 1
    title=$(timeout 30 xdotool search --sync --onlyvisible --all --class "$class" --name "$query" getwindowname %@)
    printf 'Opened in %s: %s\n' "$class" "$title"
}
open_result 'Drill text sample' xed
open_result 'Drill folder sample' nemo
