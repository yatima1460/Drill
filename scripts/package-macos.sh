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
source_app=target/swift-ui/Drill.app
arch=$(uname -m)
plist="$source_app/Contents/Info.plist"
version=$(/usr/bin/plutil -extract CFBundleShortVersionString raw -o - "$plist")
[[ "$(plutil -extract CFBundleIdentifier raw -o - "$plist")" == software.drill ]]
[[ "$(plutil -extract CFBundleExecutable raw -o - "$plist")" == Drill ]]
[[ "$(plutil -extract LSMinimumSystemVersion raw -o - "$plist")" == 13.0 ]]
lipo -verify_arch "$arch" "$source_app/Contents/MacOS/Drill"
otool -L "$source_app/Contents/MacOS/Drill" | grep -F '/SwiftUI.framework/' >/dev/null
codesign --verify --strict -R='identifier "software.drill"' "$source_app"
cmp LICENSE "$source_app/Contents/Resources/LICENSE"
cmp src/assets/drill-macos.icns "$source_app/Contents/Resources/Drill.icns"

mkdir -p "$work/root" "$mount"
ditto "$source_app" "$work/root/Drill.app"
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
verify_volume() {
  "$python" -I scripts/macos-dmg/check-layout.py "$mount"
  cmp scripts/macos-dmg/background.png "$mount/.background.png"
  diff -qr "$source_app" "$mount/Drill.app"
  codesign --verify --strict "$mount/Drill.app"
  [[ "$("$mount/Drill.app/Contents/MacOS/Drill" --version)" == "Drill $version" ]]
}
verify_volume
hdiutil detach "$mount"
mounted=false

if [[ ${1:-} != '--stage-only' ]]; then
  dmg="dist/Drill-macos-$arch.dmg"
  hdiutil convert "$stage" -format UDZO -ov -o "$dmg"
  hdiutil verify "$dmg"
  hdiutil attach -nobrowse -readonly -mountpoint "$mount" "$dmg"
  mounted=true
  verify_volume
fi
# Production signs this exact writable image after verifying its build-job digest.
mv -f "$stage" build/Drill-stage.dmg
