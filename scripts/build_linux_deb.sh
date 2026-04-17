#!/usr/bin/env bash
set -euo pipefail

RUN_NUMBER="${1:-${GITHUB_RUN_NUMBER:-0}}"
VERSION="1.0.${RUN_NUMBER}"

echo "Building Linux executable..."
DRILL_VERSION="${VERSION}" python setup.py build_exe

BUILD_DIR="$(find build -maxdepth 1 -type d -name 'exe.linux-*' | head -n 1)"
if [ -z "${BUILD_DIR}" ]; then
  echo "Linux build directory not found under build/"
  exit 1
fi

PKG_ROOT="build/debroot"
DEB_PATH="build/Drill-v${RUN_NUMBER}-linux.deb"

echo "Packaging .deb at ${DEB_PATH}..."
rm -rf "${PKG_ROOT}"
mkdir -p "${PKG_ROOT}/DEBIAN" "${PKG_ROOT}/opt/drill" "${PKG_ROOT}/usr/bin"
cp -a "${BUILD_DIR}"/. "${PKG_ROOT}/opt/drill/"

printf '%s\n' \
  "Package: drill" \
  "Version: ${VERSION}" \
  "Section: utils" \
  "Priority: optional" \
  "Architecture: amd64" \
  "Maintainer: Drill CI <noreply@github.com>" \
  "Description: Drill fast file searcher without indexing" \
  > "${PKG_ROOT}/DEBIAN/control"

printf '%s\n' \
  '#!/usr/bin/env bash' \
  'exec /opt/drill/Drill "$@"' \
  > "${PKG_ROOT}/usr/bin/drill"

chmod 755 "${PKG_ROOT}/usr/bin/drill"
chmod 755 "${PKG_ROOT}/opt/drill/Drill"

dpkg-deb --build "${PKG_ROOT}" "${DEB_PATH}"

echo "Linux .deb build script completed."
