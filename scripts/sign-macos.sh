#!/usr/bin/env bash
set -euo pipefail
umask 077

: "${MACOS_CERTIFICATE_P12_BASE64:?missing prod signing identity}"
: "${MACOS_CERTIFICATE_PASSWORD:?missing certificate export password}"
: "${APPLE_NOTARY_KEY_P8:?missing notarization team API private key}"
: "${APPLE_NOTARY_KEY_ID:?missing notarization key ID}"
: "${APPLE_NOTARY_ISSUER_ID:?missing notarization issuer ID}"

team=ZYRW8ZPM2V
identity="Developer ID Application: Pandaware LLC ($team)"
stage=build/Drill-stage.dmg
dmg="dist/Drill-macos-$(uname -m).dmg"
bundle_id=software.drill
requirement="anchor apple generic and certificate leaf[subject.OU] = \"$team\" and certificate leaf[field.1.2.840.113635.100.6.1.13] exists"
work=$(mktemp -d "${RUNNER_TEMP:?}/drill-sign.XXXXXXXX")
keychain="$work/signing.keychain-db"
mount="$work/mount"
mounted=false
# security prints one quoted, indented path per line. Preserve spaces and order.
original_keychains=()
while IFS= read -r path; do
  path=${path#*\"}
  original_keychains+=("${path%\"}")
done < <(security list-keychains -d user)
cleanup() {
  rm -f "$work/identity.p12" "$work/notary.p8"
  security list-keychains -d user -s "${original_keychains[@]}"
  security delete-keychain "$keychain" >/dev/null 2>&1 || true
  if [[ $mounted == true ]]; then hdiutil detach "$mount" >/dev/null || return 1; fi
  rm -rf "$work"
}
trap cleanup EXIT

mkdir -p dist "$mount"
hdiutil attach -nobrowse -readwrite -mountpoint "$mount" "$stage"
mounted=true
app="$mount/Drill.app"
layout_hash=$(shasum -a 256 "$mount/.DS_Store" | cut -d' ' -f1)
plist_id=$(plutil -extract CFBundleIdentifier raw -o - "$app/Contents/Info.plist")
[[ "$plist_id" == "$bundle_id" ]] || { echo "Unexpected app identifier: $plist_id" >&2; exit 1; }
printf '%s' "$MACOS_CERTIFICATE_P12_BASE64" | base64 -D > "$work/identity.p12"
printf '%s\n' "$APPLE_NOTARY_KEY_P8" > "$work/notary.p8"
unset MACOS_CERTIFICATE_P12_BASE64 APPLE_NOTARY_KEY_P8

keychain_password=$(openssl rand -hex 32)
security create-keychain -p "$keychain_password" "$keychain"
security set-keychain-settings -lut 3600 "$keychain"
security unlock-keychain -p "$keychain_password" "$keychain"
security list-keychains -d user -s "$keychain" "${original_keychains[@]}"
security import "$work/identity.p12" -k "$keychain" -P "$MACOS_CERTIFICATE_PASSWORD" -T /usr/bin/codesign >/dev/null
unset MACOS_CERTIFICATE_PASSWORD
rm "$work/identity.p12"
security set-key-partition-list -S apple-tool:,apple: -s -k "$keychain_password" "$keychain" >/dev/null
unset keychain_password

# Select one valid leaf from this keychain, even if other identities are installed.
fingerprint=$(security find-identity -v -p codesigning "$keychain" |
  awk -F'"' -v cn="$identity" '$2 == cn { split($1, fields, " "); print fields[2] }')
[[ "$fingerprint" =~ ^[A-Fa-f0-9]{40}$ ]] || { echo "Expected exactly one valid $identity identity" >&2; exit 1; }
# CodeResources is part of the distributable app and must be readable by other users.
(umask 022; codesign --force --sign "$fingerprint" --keychain "$keychain" --options runtime --timestamp "$app")
codesign --verify --deep --strict -R="identifier \"$bundle_id\" and $requirement" "$app"

hdiutil detach "$mount"
mounted=false
hdiutil convert "$stage" -format UDZO -ov -o "$dmg"
codesign --force --sign "$fingerprint" --keychain "$keychain" --timestamp --identifier "$bundle_id.dmg" "$dmg"
security lock-keychain "$keychain"
codesign --verify --strict -R="identifier \"$bundle_id.dmg\" and $requirement" "$dmg"

xcrun notarytool submit "$dmg" --key "$work/notary.p8" --key-id "$APPLE_NOTARY_KEY_ID" \
  --issuer "$APPLE_NOTARY_ISSUER_ID" --wait --timeout 60m --output-format json > "$work/notary.json"
status=$(plutil -extract status raw -o - "$work/notary.json")
if [[ "$status" != Accepted ]]; then
  submission=$(plutil -extract id raw -o - "$work/notary.json")
  echo "Notarization $submission returned $status" >&2
  exit 1
fi
xcrun stapler staple "$dmg"
xcrun stapler validate "$dmg"
hdiutil verify "$dmg"
codesign --verify --strict -R="identifier \"$bundle_id.dmg\" and $requirement" "$dmg"
spctl --assess --type open --context context:primary-signature "$dmg"
hdiutil attach -nobrowse -readonly -mountpoint "$mount" "$dmg"
mounted=true
[[ -L "$mount/Applications" && $(readlink "$mount/Applications") == /Applications ]]
printf '%s  %s\n' "$layout_hash" "$mount/.DS_Store" | shasum -a 256 --check
cmp scripts/macos-dmg/background.png "$mount/.background.png"
codesign --verify --deep --strict -R="identifier \"$bundle_id\" and $requirement" "$mount/Drill.app"
spctl --assess --type execute "$mount/Drill.app"
