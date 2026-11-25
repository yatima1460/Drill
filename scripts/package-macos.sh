#!/usr/bin/env bash
set -euo pipefail
mkdir -p dist 'build/Drill.app/Contents/MacOS' 'build/Drill.app/Contents/Resources'
cp target/release/drill 'build/Drill.app/Contents/MacOS/Drill'
cp src/assets/drill.icns 'build/Drill.app/Contents/Resources/Drill.icns'
cat > 'build/Drill.app/Contents/Info.plist' <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Drill</string>
<key>CFBundleIdentifier</key><string>com.yatima1460.drill</string>
<key>CFBundleName</key><string>Drill</string>
<key>CFBundleDisplayName</key><string>Drill</string>
<key>CFBundleIconFile</key><string>Drill</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
/usr/bin/plutil -lint 'build/Drill.app/Contents/Info.plist'
'build/Drill.app/Contents/MacOS/Drill' --version
hdiutil create -volname Drill -srcfolder 'build/Drill.app' -ov -format UDZO "dist/Drill-macos-$(uname -m).dmg"
hdiutil verify "dist/Drill-macos-$(uname -m).dmg"
