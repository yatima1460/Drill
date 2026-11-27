#!/bin/bash
set -e
cd "$(dirname "$0")"
. scripts/launcher-env.sh
make test-core
read -r -p "Core tests finished. Press Enter to close this window..."
