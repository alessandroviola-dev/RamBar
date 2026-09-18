# RamBar

`RAM 61%`

A tiny native macOS menu bar utility that shows current RAM usage.

## What it does

RamBar keeps one whole-number RAM utilization value visible in the menu bar. Its menu contains only Refresh, Launch at Login, and Quit.

## Why RAM usage on macOS is different

macOS uses otherwise idle memory for caches. RamBar estimates meaningful used physical memory rather than using the misleading `physical memory - free memory` shortcut.

The current accounting was manually validated against Activity Monitor on an 8 GB Apple Silicon Mac. Under a many-application workload, Activity Monitor reported 6.13 GB used (76.6%) while RamBar displayed `RAM 76%`.

## Download

Normal users should download the latest compiled `RamBar-vX.Y.Z-macOS.zip` from [GitHub Releases](https://github.com/alessandroviola-dev/RamBar/releases). The download is ready to use: Xcode, Swift, Homebrew, and Command Line Tools are **not** required.

## Installation

1. Download `RamBar-vX.Y.Z-macOS.zip` from GitHub Releases.
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

To create the release bundle and ZIP used by CI, run `./scripts/build-release.sh`.

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

## Limitations

RamBar shows RAM utilization, not Apple's Memory Pressure indicator. A percentage alone does not diagnose a memory problem, and independently sampled values can differ slightly from Activity Monitor at any instant.

## License

MIT.
