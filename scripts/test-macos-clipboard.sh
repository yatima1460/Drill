#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$repo_root"

scratch="$(mktemp -d "${TMPDIR:-/tmp}/drill-clipboard-test.XXXXXX")"
trap 'rm -rf -- "$scratch"' EXIT
fixture="$scratch/clipboard-test"
xcrun --sdk macosx clang -fobjc-arc -Wall -Wextra -Werror -framework AppKit \
    crates/drill-macos/src/clipboard.m crates/drill-macos/tests/clipboard.m \
    -o "$fixture"

if "$fixture"; then
    exit 0
else
    result=$?
fi

# EX_UNAVAILABLE means the process could not connect to a real pasteboard.
# Keep assertion failures visible and retry only in this user's GUI session.
user_id="$(id -u)"
if [[ "$result" -eq 69 ]] && launchctl print "gui/$user_id" >/dev/null 2>&1; then
    echo "Retrying the private pasteboard test in the logged-in macOS session."
    launchctl asuser "$user_id" "$fixture"
else
    exit "$result"
fi
