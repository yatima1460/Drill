#!/usr/bin/env bash
set -euo pipefail
if [[ $# -gt 1 || (${1:-} != '' && ${1:-} != '--stage-only') ]]; then
  echo 'Usage: package-macos.sh [--stage-only]' >&2
  exit 2
fi
mkdir -p build dist
work=$(mktemp -d "$PWD/build/dmg.XXXXXXXX")
mount="$work/mount"
mounted=false
cleanup() {
  if [[ $mounted == true ]]; then hdiutil detach "$mount" || return 1; fi
  rm -rf "$work"
}
trap cleanup EXIT
app="$work/root/Drill.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$mount"
licenses="$app/Contents/Resources/licenses/emoji"
mkdir -p "$licenses"
cp src/assets/emoji/{NOTICE,LICENSE-TWEMOJI,LICENSE-UNICODE} "$licenses/"
install -m 755 target/release/drill "$app/Contents/MacOS/Drill"
cp src/assets/drill-macos.icns "$app/Contents/Resources/Drill.icns"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Drill</string>
<key>CFBundleIdentifier</key><string>software.drill</string>
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
/usr/bin/plutil -lint "$app/Contents/Info.plist"
ln -s /Applications "$work/root/Applications"
cp scripts/macos-dmg/background.png "$work/root/.background.png"
python3 -m venv build/dmg-tools
python=build/dmg-tools/bin/python
"$python" -m pip install --disable-pip-version-check --require-hashes --only-binary=:all: \
  -r scripts/macos-dmg/requirements.txt

# The extra room allows codesign to replace the executable on the staged volume.
root_kib=$(du -sk "$work/root" | cut -f1)
stage="$work/Drill-stage.dmg"
hdiutil create -volname Drill -fs HFS+ -srcfolder "$work/root" -size "$((root_kib + 32768))k" -format UDRW "$stage"
hdiutil attach -nobrowse -readwrite -mountpoint "$mount" "$stage"
mounted=true
"$python" -I scripts/macos-dmg/layout.py "$mount"
if [[ ${1:-} == '--stage-only' ]]; then
  cmp target/release/drill "$mount/Drill.app/Contents/MacOS/Drill"
  "$python" -I scripts/macos-dmg/check-layout.py "$mount"
fi
hdiutil detach "$mount"
mounted=false
if [[ ${1:-} == '--stage-only' ]]; then
  mv -f "$stage" build/Drill-stage.dmg
  exit 0
fi

dmg="dist/Drill-macos-$(uname -m).dmg"
hdiutil convert "$stage" -format UDZO -ov -o "$dmg"
hdiutil verify "$dmg"
hdiutil attach -nobrowse -readonly -mountpoint "$mount" "$dmg"
mounted=true
"$python" -I scripts/macos-dmg/check-layout.py "$mount"
cmp scripts/macos-dmg/background.png "$mount/.background.png"
bundle_id=$(/usr/bin/plutil -extract CFBundleIdentifier raw -o - "$mount/Drill.app/Contents/Info.plist")
[[ "$bundle_id" == 'software.drill' ]] || { echo "Unexpected bundle identifier: $bundle_id" >&2; exit 1; }
"$mount/Drill.app/Contents/MacOS/Drill" --version
