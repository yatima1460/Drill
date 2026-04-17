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
