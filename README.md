# RamBar

`RAM 61%`

A tiny native macOS menu bar utility that shows current RAM usage.

## What it does

RamBar keeps one whole-number RAM utilization value visible in the menu bar. Its menu contains only Refresh, Launch at Login, and Quit.

## Why RAM usage on macOS is different

macOS uses otherwise idle memory for caches. RamBar estimates meaningful used physical memory rather than using the misleading `physical memory - free memory` shortcut.

The current accounting was manually validated against Activity Monitor on an 8 GB Apple Silicon Mac. Under a many-application workload, Activity Monitor reported 6.13 GB used (76.6%) while RamBar displayed `RAM 76%`.

## Install

```bash
git clone https://github.com/Ilcoach/RamBar.git
cd RamBar
./install.sh
```

## Requirements

macOS 13 or later, Apple Silicon, and Swift/Xcode Command Line Tools.

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
