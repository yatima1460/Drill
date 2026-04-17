#!/usr/bin/env bash
set -euo pipefail

RUN_NUMBER="${1:-${GITHUB_RUN_NUMBER:-1}}"
PKGVER="1.0.${RUN_NUMBER}"
PKGREL="1"
PKGNAME="drill-bin"
PYTHON_BIN="${PYTHON_BIN:-python3}"

echo "Building Linux executable for Arch package..."
DRILL_VERSION="${PKGVER}" "${PYTHON_BIN}" setup.py build_exe

BUILD_DIR="$(find build -maxdepth 1 -type d -name 'exe.linux-*' | head -n 1)"
if [ -z "${BUILD_DIR}" ]; then
  echo "Linux build directory not found under build/"
  exit 1
fi

# Work around intermittent cx_Freeze/stdlib `re` packaging issues observed on
# Python 3.14 in Arch CI: ensure re helper modules are present in frozen lib.
RE_DEST_DIR="${BUILD_DIR}/lib/re"
RE_SRC_DIR="$("${PYTHON_BIN}" - <<'PY'
import os
import re
print(os.path.dirname(re.__file__))
PY
)"

if [ -n "${RE_SRC_DIR}" ] && [ -d "${RE_SRC_DIR}" ]; then
  mkdir -p "${RE_DEST_DIR}"
  for mod in _casefix _compiler _constants _parser; do
    if [ ! -f "${RE_DEST_DIR}/${mod}.pyc" ] && [ ! -f "${RE_DEST_DIR}/${mod}.py" ]; then
      if [ -f "${RE_SRC_DIR}/${mod}.py" ]; then
        cp -f "${RE_SRC_DIR}/${mod}.py" "${RE_DEST_DIR}/${mod}.py"
      fi
    fi
  done
fi

ARCH_ROOT="build/arch"
PKGBUILD_DIR="${ARCH_ROOT}/pkgbuild"
rm -rf "${PKGBUILD_DIR}"
mkdir -p "${PKGBUILD_DIR}"

cp -a "${BUILD_DIR}" "${PKGBUILD_DIR}/drill-linux"
tar -C "${PKGBUILD_DIR}" -czf "${PKGBUILD_DIR}/drill-linux.tar.gz" drill-linux

TEMPLATE_PATH="scripts/PKGBUILD.archlinux"
if [ ! -f "${TEMPLATE_PATH}" ]; then
  echo "PKGBUILD template not found: ${TEMPLATE_PATH}"
  exit 1
fi

sed -e "s/__PKGVER__/${PKGVER}/g" -e "s/__PKGREL__/${PKGREL}/g" "${TEMPLATE_PATH}" > "${PKGBUILD_DIR}/PKGBUILD"

(
  cd "${PKGBUILD_DIR}"
  makepkg -f --noconfirm
)

mkdir -p "${ARCH_ROOT}"
PKG_FILE="$(find "${PKGBUILD_DIR}" -maxdepth 1 -type f -name "${PKGNAME}-${PKGVER}-${PKGREL}-x86_64.pkg.tar.*" | head -n 1)"
if [ -z "${PKG_FILE}" ]; then
  echo "Arch package file not found."
  exit 1
fi

cp -f "${PKG_FILE}" "${ARCH_ROOT}/"
echo "Built Arch package: ${ARCH_ROOT}/$(basename "${PKG_FILE}")"
