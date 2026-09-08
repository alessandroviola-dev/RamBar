#!/bin/bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
source "$ROOT/scripts/common.sh"
check_existing_app

if [[ ! -e "$APP" ]]; then
    printf 'RamBar is not installed at %s\n' "$APP"
    exit 0
fi
stop_installed_app
# Run inside the bundle so SMAppService.mainApp identifies the installed app.
"$APP/Contents/MacOS/RamBar" --unregister-login || fail 'Launch at Login could not be removed; app retained. Disable it in System Settings and retry.'
rm -rf -- "$APP"
printf 'RamBar uninstalled. Project source and user files were left untouched.\n'
