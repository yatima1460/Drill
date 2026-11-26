#!/bin/bash
set -e
cd "$(dirname "$0")"
. scripts/launcher-env.sh
cargo run --release
