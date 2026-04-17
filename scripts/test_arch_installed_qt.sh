#!/usr/bin/env bash
set -euo pipefail

RUN_NUMBER="${1:-${GITHUB_RUN_NUMBER:-1}}"

if ! command -v drill >/dev/null 2>&1; then
  echo "drill command not found. Install the Arch package before testing."
  exit 1
fi

echo "Running installed Arch Qt headless smoke test..."
export QT_QPA_PLATFORM=offscreen
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/qt-runtime}"
mkdir -p "${XDG_RUNTIME_DIR}"
chmod 700 "${XDG_RUNTIME_DIR}"

set +e
timeout 10s drill
status=$?
set -e

if [ "$status" -eq 124 ]; then
  echo "Installed Arch Qt headless smoke test completed (expected timeout)."
elif [ "$status" -eq 0 ]; then
  echo "drill exited immediately with success."
else
  echo "drill exited with unexpected status: $status"
  exit "$status"
fi
