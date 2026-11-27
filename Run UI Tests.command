#!/bin/bash
set -e
cd "$(dirname "$0")"
. scripts/launcher-env.sh
make test-ui
read -r -p "UI tests finished. Press Enter to close this window..."
