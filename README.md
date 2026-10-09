# RamBar

`RAM 61%`

A tiny native macOS menu bar utility that shows current RAM usage.

## Requirements

- macOS 13 Ventura or later
- Apple Silicon Mac (arm64)

Intel Macs are not currently supported.

## What it does

RamBar keeps one whole-number RAM utilization value visible in the menu bar. Its menu contains only Refresh, Launch at Login, and Quit.

## Why RAM usage on macOS is different

macOS uses otherwise idle memory for caches. RamBar estimates meaningful used physical memory rather than using the misleading `physical memory - free memory` shortcut.

The current accounting was manually validated against Activity Monitor on an 8 GB Apple Silicon Mac. Under a many-application workload, Activity Monitor reported 6.13 GB used (76.6%) while RamBar displayed `RAM 76%`.

The displayed value is an estimate and may differ slightly from Activity Monitor because Apple does not provide a stable public formula for its memory percentage.

## Download

Current release: **v0.1.1 (build 2)**.

Normal users should download the compiled `RamBar-v0.1.1-macOS.zip` from [GitHub Releases](https://github.com/alessandroviola-dev/RamBar/releases). The ZIP contains the ready-to-use macOS application: Xcode, Swift, Homebrew, and Command Line Tools are **not** required.

## Installation

1. Download `RamBar-v0.1.1-macOS.zip` from GitHub Releases.
2. Extract it to obtain `RamBar.app`.
3. Drag `RamBar.app` to `/Applications`.
4. Open RamBar.

The current builds are ad-hoc signed and are not yet Developer ID notarized. If Gatekeeper blocks the first launch, control-click the app, choose **Open**, then confirm **Open**; alternatively approve it in **System Settings → Privacy & Security**. Do not disable Gatekeeper globally.

## Build from source (developers)

macOS 13 or later, Apple Silicon, and Swift/Xcode Command Line Tools are needed only by developers building from source:

```bash
git clone https://github.com/alessandroviola-dev/RamBar.git
cd RamBar
./install.sh
```

The installer uses only `/Applications/RamBar.app`; `/Applications` must be writable, with no per-user fallback. Verified legacy copies in `~/Applications` are backed up and removed only after successful installation; failures restore both copies. Invalid or symlinked bundles are refused. After migration, check Launch at Login in the canonical app.

To create the release bundle and ZIP used by CI, run `./scripts/build-release.sh` (Python 3 is required for packaging checks). Existing output is never overwritten; for a local build use a fresh directory:

```bash
OUTPUT_DIR="$(mktemp -d /tmp/RamBar-package.XXXXXX)" ./scripts/build-release.sh
```

Packaging uses an isolated arm64 build, remaps compiler paths and omits linker debug-map paths before signing. A fail-closed binary privacy scan checks the bundle, ZIP entries and extracted files. See `RELEASE_PRIVACY.md` for the local v0.1.1 checkpoint.

## How it works

- Swift and AppKit
- public native Mach VM statistics
- no subprocess polling
- approximately two-second refresh interval

RamBar estimates Activity Monitor-style Memory Used using physical RAM minus reclaimable pages: true free memory, file-backed external/cache pages, and purgeable pages. Speculative pages are removed from `free_count` because they are already file-backed; compressor memory is implicit in the physical-minus-reclaimable result and is not added again.

## Privacy

- fully local
- no tracking or telemetry
- no network access
- no personal data
- privacy manifest included

## Development

```bash
swift build
swift build -c release
swift test
```

See `TESTING.md` for automated verification and real Activity Monitor comparisons.

## Uninstall

```bash
./uninstall.sh
```

Removes only verified `/Applications/RamBar.app` and any legacy `~/Applications/RamBar.app`, unregistering their login items first. Unrelated apps and user files are left untouched.

## Limitations

RamBar shows RAM utilization, not Apple's Memory Pressure indicator. A percentage alone does not diagnose a memory problem, and independently sampled values can differ slightly from Activity Monitor at any instant.

## License

MIT.
