#!/bin/bash
# Creates an arm64, ad-hoc-signed app bundle and a source-free distributable ZIP.
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
APP_NAME="RamBar"
BUNDLE_ID="com.alessandroviola.rambar"
INFO_PLIST="$ROOT/Resources/Info.plist"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT/dist}"
# Leave these unset for the reproducible ad-hoc path used by CI. A future release
# can set SIGNING_IDENTITY to a Developer ID Application identity and NOTARY_PROFILE
# to a notarytool keychain profile; neither credential is stored in this repository.
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

fail() { printf '%s\n' "build-release: $*" >&2; exit 1; }
[[ "$(uname -s)" == "Darwin" ]] || fail "macOS is required."
command -v swift >/dev/null || fail "Swift is required only to build a release. End users install the ZIP."
command -v codesign >/dev/null || fail "codesign is required."
command -v ditto >/dev/null || fail "ditto is required."
command -v python3 >/dev/null || fail "Python 3 is required for fail-closed privacy verification."
[[ -f "$INFO_PLIST" && -f "$ROOT/Resources/AppIcon.icns" ]] || fail "Missing bundle metadata or application icon."

version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")
build=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")
[[ -n "$version" && -n "$build" ]] || fail "Bundle version is missing."

cd "$ROOT"
# A fresh scratch directory prevents reuse of objects from a contaminated build.
# Swift mapping covers source/debug metadata; ld -S omits the OSO debug map,
# whose object paths are linker-generated and not covered by Swift's mapping.
stage=$(mktemp -d "/tmp/${APP_NAME}-release.XXXXXX")
trap 'rm -rf "$stage"' EXIT
scratch="$stage/build"
swift build --scratch-path "$scratch" -c release --arch arm64 \
    -Xswiftc -file-prefix-map -Xswiftc "$ROOT=/Source" \
    -Xswiftc -file-prefix-map -Xswiftc "$stage=/Build" \
    -Xswiftc -file-compilation-dir -Xswiftc /Source \
    -Xlinker -S
bin_path=$(swift build --scratch-path "$scratch" -c release --arch arm64 --show-bin-path)
executable="$bin_path/$APP_NAME"
[[ -x "$executable" ]] || fail "Release executable was not produced."
app="$stage/$APP_NAME.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$INFO_PLIST" "$app/Contents/Info.plist"
cp "$ROOT/Resources/PrivacyInfo.xcprivacy" "$app/Contents/Resources/PrivacyInfo.xcprivacy"
cp "$ROOT/Resources/AppIcon.icns" "$app/Contents/Resources/AppIcon.icns"
cp "$executable" "$app/Contents/MacOS/$APP_NAME"
chmod 755 "$app/Contents/MacOS/$APP_NAME"

plutil -lint "$app/Contents/Info.plist" "$app/Contents/Resources/PrivacyInfo.xcprivacy" >/dev/null
[[ $(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist") == "$BUNDLE_ID" ]] || fail "Unexpected bundle identifier."
[[ $(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$app/Contents/Info.plist") == "$APP_NAME" ]] || fail "Unexpected executable name."
[[ $(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$app/Contents/Info.plist") == "AppIcon" ]] || fail "App icon is not declared."

# Keep the release portable: it must not load a product from SwiftPM's build directory.
otool -L "$app/Contents/MacOS/$APP_NAME" > "$stage/dependencies.txt"
if grep -E '/\.build/|SwiftTerm\.framework' "$stage/dependencies.txt" >/dev/null; then
    fail "The executable has a SwiftPM build-directory runtime dependency."
else
    status=$?
    [[ $status == 1 ]] || fail "Dependency scan failed."
fi
python3 "$ROOT/scripts/privacy-scan.py" bundle "$app"
[[ -z "$NOTARY_PROFILE" || "$SIGNING_IDENTITY" != "-" ]] || fail "Notarization requires a Developer ID signing identity."
codesign --force --deep --sign "$SIGNING_IDENTITY" --identifier "$BUNDLE_ID" "$app"
codesign --verify --deep --strict --verbose=2 "$app"

# The archive whitelist makes it impossible to ship repository sources or local build data.
mkdir -p "$OUTPUT_DIR"
zip="$OUTPUT_DIR/$APP_NAME-v$version-macOS.zip"
[[ ! -e "$OUTPUT_DIR/$APP_NAME.app" && ! -e "$zip" ]] || fail "Output already exists; choose a fresh OUTPUT_DIR to preserve evidence."
cp -R "$app" "$OUTPUT_DIR/$APP_NAME.app"
ditto -c -k --sequesterRsrc --keepParent "$OUTPUT_DIR/$APP_NAME.app" "$zip"
if [[ -n "$NOTARY_PROFILE" ]]; then
    xcrun notarytool submit "$zip" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$OUTPUT_DIR/$APP_NAME.app"
    rm -f "$zip"
    ditto -c -k --sequesterRsrc --keepParent "$OUTPUT_DIR/$APP_NAME.app" "$zip"
fi
unzip -Z1 "$zip" > "$stage/entries.txt"
if grep -Ev "^${APP_NAME}\.app(/|$)" "$stage/entries.txt" >/dev/null; then
    fail "ZIP contains files outside the application bundle."
else
    status=$?
    [[ $status == 1 ]] || fail "ZIP whitelist scan failed."
fi
if grep -E '(^|/)(\.build|DerivedData|\.env|.*\.(swift|pem|p12|cer|key)|.*\.log)(/|$)' "$stage/entries.txt" >/dev/null; then
    fail "ZIP contains excluded local or credential material."
else
    status=$?
    [[ $status == 1 ]] || fail "ZIP exclusions scan failed."
fi
python3 "$ROOT/scripts/privacy-scan.py" zip "$zip"

extract="$stage/extracted"
mkdir "$extract"
unzip -q "$zip" -d "$extract"
extracted="$extract/$APP_NAME.app"
[[ -x "$extracted/Contents/MacOS/$APP_NAME" && -s "$extracted/Contents/Resources/AppIcon.icns" ]] || fail "Extracted bundle is incomplete."
plutil -lint "$extracted/Contents/Info.plist" >/dev/null
python3 "$ROOT/scripts/privacy-scan.py" bundle "$extracted"
codesign --verify --deep --strict --verbose=2 "$extracted"
printf 'Built %s (version %s, build %s)\nZIP: %s\n' "$OUTPUT_DIR/$APP_NAME.app" "$version" "$build" "$zip"
