#!/usr/bin/env bash
set -euo pipefail
mkdir -p dist 'build/dmg-root/Drill.app/Contents/MacOS' 'build/dmg-root/Drill.app/Contents/Resources'
cp target/release/drill 'build/dmg-root/Drill.app/Contents/MacOS/Drill'
cp src/assets/drill-macos.icns 'build/dmg-root/Drill.app/Contents/Resources/Drill.icns'
cat > 'build/dmg-root/Drill.app/Contents/Info.plist' <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Drill</string>
<key>CFBundleIdentifier</key><string>com.yatima1460.drill</string>
<key>CFBundleName</key><string>Drill</string>
<key>CFBundleDisplayName</key><string>Drill</string>
<key>CFBundleIconFile</key><string>Drill</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>2.0.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSDesktopFolderUsageDescription</key><string>Drill searches your Desktop for filenames.</string>
<key>NSDocumentsFolderUsageDescription</key><string>Drill searches your Documents for filenames.</string>
<key>NSDownloadsFolderUsageDescription</key><string>Drill searches your Downloads for filenames.</string>
<key>NSNetworkVolumesUsageDescription</key><string>Drill searches network volumes for filenames.</string>
<key>NSRemovableVolumesUsageDescription</key><string>Drill searches removable volumes for filenames.</string>
<key>NSFileProviderDomainUsageDescription</key><string>Drill searches cloud folders for filenames.</string>
</dict></plist>
PLIST
/usr/bin/plutil -lint 'build/dmg-root/Drill.app/Contents/Info.plist'
'build/dmg-root/Drill.app/Contents/MacOS/Drill' --version
hdiutil create -volname Drill -srcfolder 'build/dmg-root' -ov -format UDZO "dist/Drill-macos-$(uname -m).dmg"
hdiutil verify "dist/Drill-macos-$(uname -m).dmg"

mkdir -p build/dmg-check
hdiutil attach -nobrowse -readonly -mountpoint "$PWD/build/dmg-check" "dist/Drill-macos-$(uname -m).dmg"
trap 'hdiutil detach "$PWD/build/dmg-check" || true' EXIT
'build/dmg-check/Drill.app/Contents/MacOS/Drill' --version
