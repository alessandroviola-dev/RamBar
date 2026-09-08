#!/bin/bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
source "$ROOT/scripts/common.sh"

[[ $(uname -m) == arm64 ]] || fail 'RamBar currently requires native Apple Silicon (arm64).'
[[ $(/usr/sbin/sysctl -in sysctl.proc_translated 2>/dev/null || printf 0) == 0 ]] || fail 'Run the installer natively, not under Rosetta.'
command -v swift >/dev/null || fail 'Swift / Xcode Command Line Tools are required.'
command -v codesign >/dev/null || fail 'codesign is required.'
check_existing_app

cd "$ROOT"
swift build -c release --arch arm64 -Xswiftc -warnings-as-errors
EXECUTABLE=$(swift build -c release --arch arm64 --show-bin-path)/RamBar
[[ -x "$EXECUTABLE" ]] || fail 'Release executable was not produced.'
/usr/bin/lipo -archs "$EXECUTABLE" | /usr/bin/grep -qw arm64 || fail 'Release executable is not arm64.'
/usr/bin/plutil -lint Resources/Info.plist >/dev/null
/usr/bin/plutil -lint Resources/PrivacyInfo.xcprivacy >/dev/null

STAGE=$(mktemp -d "${TMPDIR:-/tmp}/RamBar.XXXXXX")
BACKUP=""
COMMITTED=0
cleanup() {
    rm -rf -- "$STAGE"
    if [[ $COMMITTED != 1 && -n $BACKUP && -e $BACKUP && ! -e $APP ]]; then mv -- "$BACKUP" "$APP"; fi
}
trap cleanup EXIT
mkdir -p "$STAGE/RamBar.app/Contents/MacOS" "$STAGE/RamBar.app/Contents/Resources"
cp "$EXECUTABLE" "$STAGE/RamBar.app/Contents/MacOS/RamBar"
cp Resources/Info.plist "$STAGE/RamBar.app/Contents/Info.plist"
cp Resources/PrivacyInfo.xcprivacy "$STAGE/RamBar.app/Contents/Resources/PrivacyInfo.xcprivacy"
/usr/bin/codesign --force --sign - --timestamp=none "$STAGE/RamBar.app"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$STAGE/RamBar.app" >/dev/null

mkdir -p "$HOME/Applications"
stop_installed_app
if [[ -e $APP ]]; then
    BACKUP=$(mktemp -d "${TMPDIR:-/tmp}/RamBar-backup.XXXXXX")/RamBar.app
    mv -- "$APP" "$BACKUP"
fi
mv "$STAGE/RamBar.app" "$APP"
/usr/bin/open "$APP"
for _ in {1..30}; do
    [[ -n $(installed_pids) ]] && break
    sleep 0.1
done
if [[ -z $(installed_pids) ]]; then
    rm -rf -- "$APP"
    [[ -n $BACKUP && -e $BACKUP ]] && mv -- "$BACKUP" "$APP"
    fail 'New app did not remain running; previous installation was restored.'
fi
cmp -s Resources/PrivacyInfo.xcprivacy "$APP/Contents/Resources/PrivacyInfo.xcprivacy" || fail 'Installed privacy manifest differs from source.'
COMMITTED=1
[[ -z $BACKUP ]] || rm -rf -- "${BACKUP%/RamBar.app}"
printf 'RamBar installed and running: %s\n' "$APP"
