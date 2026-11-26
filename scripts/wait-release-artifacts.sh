#!/usr/bin/env bash
set -euo pipefail
# Upload completion and artifact-list visibility can be separated by seconds.
# Never publish a release until all named platform artifacts are visible.
for attempt in {1..24}; do
  names="$(gh api "repos/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}/artifacts?per_page=100" --jq '.artifacts[] | select(.expired == false) | .name' || true)"
  ready=true
  for name in drill-linux drill-macos-signed drill-windows; do
    if ! grep -Fxq "$name" <<< "$names"; then ready=false; fi
  done
  if "$ready"; then exit 0; fi
  echo "Waiting for release artifacts (attempt $attempt/24)"
  sleep 5
done
echo 'Timed out waiting for all three release artifacts' >&2
exit 1
