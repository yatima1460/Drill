#!/usr/bin/env bash
set -euo pipefail

RUN_NUMBER="${1:-${GITHUB_RUN_NUMBER:-1}}"

if ! command -v drill >/dev/null 2>&1; then
  echo "drill command not found. Install the Arch package before testing."
  exit 1
fi

MARKER_NAME="drill-smoke-marker-arch-${RUN_NUMBER}.txt"
mkdir -p "${HOME}/Desktop"
MARKER_PATH="${HOME}/Desktop/${MARKER_NAME}"
touch "${MARKER_PATH}"
trap 'rm -f "${MARKER_PATH}"' EXIT

export DRILL_EXPECT_RESULT_CONTAINS
DRILL_EXPECT_RESULT_CONTAINS="$(echo "${MARKER_PATH}" | tr '[:upper:]' '[:lower:]')"
export DRILL_CLI_MAX_SECONDS="120"

drill --cli "${MARKER_NAME}"
echo "Arch installed CLI smoke test completed."
