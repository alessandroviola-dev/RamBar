# Installer verification (local, 2026-10-08)

Canonical destination: `/Applications/RamBar.app`. No per-user installation fallback or creation of `~/Applications`. Existing verified canonical and legacy bundles are backed up until canonical launch and privacy-manifest verification succeed; rollback restores their original paths. Uninstall preflights both locations. Bundle ID, executable presence and strict signature checks are required. Symlinked bundles or Applications directories are refused. Only processes whose command starts with the exact installed executable path may be signalled, with a second check before TERM.

## Results

- `bash -n install.sh uninstall.sh scripts/common.sh scripts/build-release.sh`: PASS.
- `python3 scripts/test-installer.py`: 15 scenarios PASS (fresh, canonical-only, legacy-only, coexistence, legacy/canonical wrong IDs, bad signature, bundle/parent symlinks, rollback on launch failure or missing process, uninstall, absent uninstall, unregister failure retention, exact executable process selection).
- `swift test`: 9 XCTest tests PASS, zero failures.
- `swift build -c release --arch arm64 -Xswiftc -warnings-as-errors`: PASS.
- `git diff --check`: PASS.
- Read-only installed bundle ID and strict signature verification: PASS.
- Installed process retained PID 34192; executable modification time remained 2026-09-08. No real install/uninstall, app termination, GitHub Actions, push or release creation.

## Closure validation (2026-10-08)

The 15 installer scenarios, 9 XCTest tests (zero failures), Bash syntax, release arm64 build with warnings-as-errors, and diff whitespace checks were rerun successfully before the local checkpoint. No operational bundle, preferences or historical backup was modified. BTM_UNVERIFIED: the single authorized elevated read-only dump required sudo authentication; launchctl/LaunchAgents inspection did not establish enabled Login Item status. Real GUI, migration, reboot and publication remain deferred.

## Limits

Sandbox tests use disposable script copies, redirected paths and mocked OS tools, including Bash `kill` in the process test. Signing/launch/login-item behavior is simulated, not tested end-to-end. Real migration and login approval remain manual checks; check Launch at Login after migrating a legacy copy. Permission/disk failures and rollback recovery retention require additional manual verification. A failed rollback retains staging instead of deleting backups.

`scripts/build-release.sh` was inspected and syntax-checked, not executed: it packages in `dist` and does not install applications.
