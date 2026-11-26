#!/usr/bin/env bash
set -euo pipefail
exec "${WINE:-wine}" "$@"
