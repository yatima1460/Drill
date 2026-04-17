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

APPDIR="build/AppDir"
APPIMAGE_PATH="build/Drill-v${RUN_NUMBER}-linux.AppImage"
APPIMAGETOOL="build/appimagetool-x86_64.AppImage"

echo "Preparing AppDir at ${APPDIR}..."
rm -rf "${APPDIR}"
mkdir -p "${APPDIR}/usr/lib/drill"
mkdir -p "${APPDIR}/usr/bin"
mkdir -p "${APPDIR}/usr/share/applications"
mkdir -p "${APPDIR}/usr/share/icons/hicolor/scalable/apps"
mkdir -p "${APPDIR}/usr/share/metainfo"

cp -a "${BUILD_DIR}/." "${APPDIR}/usr/lib/drill/"
chmod 755 "${APPDIR}/usr/lib/drill/Drill"

cat > "${APPDIR}/AppRun" <<'EOF'
#!/usr/bin/env bash
HERE="$(dirname "$(readlink -f "${0}")")"
exec "${HERE}/usr/lib/drill/Drill" "$@"
EOF
chmod 755 "${APPDIR}/AppRun"

cat > "${APPDIR}/Drill.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Drill
Exec=AppRun
Icon=drill
Categories=Utility;
Terminal=false
EOF

cat > "${APPDIR}/usr/share/metainfo/Drill.appdata.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<component type="desktop-application">
  <id>Drill.desktop</id>
  <metadata_license>CC0-1.0</metadata_license>
  <project_license>GPL-2.0-only</project_license>
  <name>Drill</name>
  <summary>Fast file search without indexing</summary>
  <description>
    <p>Drill is a fast desktop file search app that works without building a background index.</p>
  </description>
  <launchable type="desktop-id">Drill.desktop</launchable>
  <provides>
    <binary>drill</binary>
  </provides>
  <url type="homepage">https://github.com/yatima1460/Drill</url>
</component>
EOF

cp -f "${APPDIR}/Drill.desktop" "${APPDIR}/usr/share/applications/Drill.desktop"
cp -f "src/assets/drill.svg" "${APPDIR}/drill.svg"
cp -f "src/assets/drill.svg" "${APPDIR}/usr/share/icons/hicolor/scalable/apps/drill.svg"
ln -sf drill.svg "${APPDIR}/.DirIcon"

if [ ! -x "${APPIMAGETOOL}" ]; then
  echo "Downloading appimagetool..."
  curl -fsSL -o "${APPIMAGETOOL}" \
    "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
  chmod 755 "${APPIMAGETOOL}"
fi

echo "Building AppImage at ${APPIMAGE_PATH}..."
ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 "${APPIMAGETOOL}" "${APPDIR}" "${APPIMAGE_PATH}"
chmod 755 "${APPIMAGE_PATH}"

echo "Linux AppImage build script completed."
