#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -n "${PYTHON_BIN:-}" ]]; then
  PYTHON="$PYTHON_BIN"
elif [[ -x "$ROOT_DIR/.venv/bin/python" ]]; then
  PYTHON="$ROOT_DIR/.venv/bin/python"
else
  PYTHON="python3"
fi

echo "[build_mac] Root: $ROOT_DIR"
echo "[build_mac] Python: $($PYTHON --version)"

if [[ "${INSTALL_DEPS:-1}" == "1" ]]; then
  echo "[build_mac] Installing build dependencies"
  "$PYTHON" -m pip install --upgrade pip
  "$PYTHON" -m pip install -r requirements-cd.txt
fi

echo "[build_mac] Building macOS .app"
"$PYTHON" setup.py bdist_mac

echo "[build_mac] Building macOS .dmg"
"$PYTHON" setup.py bdist_dmg

echo "[build_mac] Build complete"
echo "[build_mac] App artifacts:"
find build -maxdepth 4 -name '*.app' -print || true
echo "[build_mac] DMG artifacts:"
find build -maxdepth 3 -name '*.dmg' -print || true
