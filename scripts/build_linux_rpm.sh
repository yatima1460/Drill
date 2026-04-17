#!/usr/bin/env bash
set -euo pipefail

RUN_NUMBER="${1:-${GITHUB_RUN_NUMBER:-1}}"
VERSION="1.0.${RUN_NUMBER}"
RELEASE="1"
PYTHON_BIN="${PYTHON_BIN:-python3}"

echo "Building Linux executable for RPM..."
DRILL_VERSION="${VERSION}" "${PYTHON_BIN}" setup.py build_exe

BUILD_DIR="$(find build -maxdepth 1 -type d -name 'exe.linux-*' | head -n 1)"
if [ -z "${BUILD_DIR}" ]; then
  echo "Linux build directory not found under build/"
  exit 1
fi

RPM_ROOT="build/rpm/rpmbuild"
SPEC_TEMPLATE="scripts/drill.spec.rpm"
SPEC_PATH="${RPM_ROOT}/SPECS/drill.spec"

rm -rf "${RPM_ROOT}"
mkdir -p "${RPM_ROOT}/BUILD" "${RPM_ROOT}/BUILDROOT" "${RPM_ROOT}/RPMS" "${RPM_ROOT}/SOURCES" "${RPM_ROOT}/SPECS" "${RPM_ROOT}/SRPMS"

TMP_SRC_DIR="build/rpm/drill-linux"
rm -rf "${TMP_SRC_DIR}"
cp -a "${BUILD_DIR}" "${TMP_SRC_DIR}"
tar -C "build/rpm" -czf "${RPM_ROOT}/SOURCES/drill-linux.tar.gz" drill-linux

if [ ! -f "${SPEC_TEMPLATE}" ]; then
  echo "RPM spec template not found: ${SPEC_TEMPLATE}"
  exit 1
fi
sed -e "s/__VERSION__/${VERSION}/g" -e "s/__RELEASE__/${RELEASE}/g" "${SPEC_TEMPLATE}" > "${SPEC_PATH}"

rpmbuild --define "_topdir $(pwd)/${RPM_ROOT}" -bb "${SPEC_PATH}"

RPM_FILE="$(find "${RPM_ROOT}/RPMS" -type f -name "drill-${VERSION}-${RELEASE}*.x86_64.rpm" | head -n 1)"
if [ -z "${RPM_FILE}" ]; then
  echo "Built RPM package not found."
  exit 1
fi

OUT_PATH="build/Drill-v${RUN_NUMBER}-linux.rpm"
cp -f "${RPM_FILE}" "${OUT_PATH}"
echo "Built RPM: ${OUT_PATH}"
