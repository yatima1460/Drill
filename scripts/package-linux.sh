#!/usr/bin/env bash
set -euo pipefail
version="2.0.0"
revision="${GITHUB_RUN_NUMBER:-1}"
for stage in build/package build/appdir build/arch; do
  licenses="$stage/usr/share/licenses/drill/emoji"
  mkdir -p "$licenses"
  cp src/assets/emoji/{NOTICE,LICENSE-TWEMOJI,LICENSE-UNICODE} "$licenses/"
done
mkdir -p dist build/package/usr/bin build/package/usr/share/applications build/package/usr/share/icons/hicolor/256x256/apps build/package/DEBIAN
install -m755 target/release/drill build/package/usr/bin/drill
install -m644 src/assets/drill.png build/package/usr/share/icons/hicolor/256x256/apps/drill.png
cat > build/package/usr/share/applications/drill.desktop <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Drill
Comment=Search files without indexing
Exec=drill
Icon=drill
Categories=Utility;FileTools;
Terminal=false
DESKTOP
cat > build/package/DEBIAN/control <<CONTROL
Package: drill
Version: ${version}-${revision}
Architecture: amd64
Maintainer: Drill contributors
Depends: libc6, libx11-6, libx11-xcb1, libxkbcommon0, libxkbcommon-x11-0, libwayland-client0, libgl1, libegl1, libgtk-3-0, xdg-utils
Description: Desktop file search without indexing
CONTROL
dpkg-deb --build --root-owner-group build/package "dist/Drill-linux-amd64.deb"
dpkg-deb --contents dist/Drill-linux-amd64.deb > build/deb-contents.txt
grep '/usr/bin/drill' build/deb-contents.txt
mkdir -p build/appdir/usr/bin build/appdir/usr/share/applications build/appdir/usr/share/icons/hicolor/256x256/apps
cp target/release/drill build/appdir/usr/bin/drill
cp build/package/usr/share/applications/drill.desktop build/appdir/drill.desktop
cp src/assets/drill.png build/appdir/drill.png
cp src/assets/drill.png build/appdir/usr/share/icons/hicolor/256x256/apps/drill.png
cat > build/appdir/AppRun <<'APPRUN'
#!/bin/sh
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
exec "$HERE/usr/bin/drill" "$@"
APPRUN
chmod +x build/appdir/AppRun
curl -fsSL https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage -o build/appimagetool
echo "b90f4a8b18967545fda78a445b27680a1642f1ef9488ced28b65398f2be7add2  build/appimagetool" | sha256sum -c -
chmod +x build/appimagetool
ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 build/appimagetool build/appdir dist/Drill-linux-x86_64.AppImage
APPIMAGE_EXTRACT_AND_RUN=1 dist/Drill-linux-x86_64.AppImage --version
mkdir -p build/arch/usr/bin build/arch/usr/share/applications build/arch/usr/share/icons/hicolor/256x256/apps
cp target/release/drill build/arch/usr/bin/drill
cp build/package/usr/share/applications/drill.desktop build/arch/usr/share/applications/
cp src/assets/drill.png build/arch/usr/share/icons/hicolor/256x256/apps/
cat > build/arch/.PKGINFO <<PKGINFO
pkgname = drill-bin
pkgver = ${version}-${revision}
pkgdesc = Desktop file search without indexing
url = https://github.com/yatima1460/Drill
builddate = $(date +%s)
packager = Drill contributors
size = $(wc -c < target/release/drill | tr -d ' ')
arch = x86_64
license = GPL-2.0-only
depend = glibc
depend = libx11
depend = libxkbcommon
depend = libxkbcommon-x11
depend = xdg-utils
depend = wayland
depend = libglvnd
depend = gtk3
PKGINFO
tar --zstd -C build/arch -cf "dist/Drill-linux-x86_64.pkg.tar.zst" .PKGINFO usr
tar --zstd -tf dist/Drill-linux-x86_64.pkg.tar.zst > build/arch-contents.txt
grep 'usr/bin/drill' build/arch-contents.txt
