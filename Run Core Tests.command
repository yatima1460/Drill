#!/bin/bash
set -e
cd "$(dirname "$0")"
. scripts/launcher-env.sh
cargo test --locked -p drill-core
read -r -p "Core tests finished. Press Enter to close this window..."
