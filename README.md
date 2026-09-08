# RamBar

`RAM 61%`

A tiny native macOS menu bar utility that shows current RAM usage.

## What it does

RamBar keeps one whole-number RAM utilization value visible in the menu bar. Its menu contains only Refresh, Launch at Login, and Quit.

## Why RAM usage on macOS is different

macOS uses otherwise idle memory for caches. RamBar estimates meaningful used physical memory rather than using the misleading `physical memory - free memory` shortcut.

## Install

```bash
git clone https://github.com/Ilcoach/RamBar.git
cd RamBar
./install.sh
```

Or install this checkout:

```bash
cd <project-root>stall.sh
```

## Requirements

macOS 13 or later, Apple Silicon, and Swift/Xcode Command Line Tools.

## How it works

- Swift and AppKit
- public native Mach VM statistics
- no subprocess polling
- approximately two-second refresh interval

The estimate is wired memory plus non-purgeable internal pages plus the compressor's physical footprint. File-backed external pages are treated as reclaimable cache, and compressor pages are counted once.

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

## Uninstall

```bash
./uninstall.sh
```

## Limitations

RamBar shows RAM utilization, not Apple's Memory Pressure indicator. A percentage alone does not diagnose a memory problem, and its documented native estimate can differ modestly from Activity Monitor's presentation.

## License

MIT.
