#!/bin/bash
# Shared safety checks for install.sh and uninstall.sh.
set -euo pipefail

fail() { printf 'RamBar: %s\n' "$*" >&2; exit 1; }
[[ $(uname -s) == Darwin ]] || fail 'macOS is required.'
[[ -n ${HOME:-} && $HOME == /* && $HOME != / ]] || fail 'HOME must be an absolute user directory.'
APP="$HOME/Applications/RamBar.app"
BUNDLE_ID=com.alessandroviola.rambar

check_existing_app() {
    [[ ! -L "$APP" ]] || fail "Refusing to replace/remove symlink: $APP"
    if [[ -e "$APP" ]]; then
        local identifier
        identifier=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist" 2>/dev/null) || fail "Not a valid RamBar bundle: $APP"
        [[ $identifier == "$BUNDLE_ID" ]] || fail "An unrelated application occupies $APP"
    fi
}

installed_pids() {
    local pid command
    for pid in $(/usr/bin/pgrep -x RamBar || true); do
        command=$(/bin/ps -p "$pid" -o command= 2>/dev/null || true)
        case "$command" in
            "$APP/Contents/MacOS/RamBar"|"$APP/Contents/MacOS/RamBar "*) printf '%s\n' "$pid" ;;
        esac
    done
}

stop_installed_app() {
    local pids pid attempt
    pids=$(installed_pids)
    [[ -n $pids ]] || return 0
    /usr/bin/osascript - "$APP" >/dev/null 2>&1 <<'APPLESCRIPT' || true
on run argv
    with timeout of 5 seconds
        tell application (item 1 of argv) to quit
    end timeout
end run
APPLESCRIPT
    for pid in $pids; do
        kill -0 "$pid" 2>/dev/null && kill -TERM "$pid" 2>/dev/null || true
        for attempt in {1..50}; do
            kill -0 "$pid" 2>/dev/null || break
            sleep 0.1
        done
        kill -0 "$pid" 2>/dev/null && fail "Could not stop RamBar (PID $pid); installation unchanged."
    done
}
