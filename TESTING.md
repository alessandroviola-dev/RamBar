# RamBar verification

All automated results below were performed on the development Mac: Apple Silicon arm64, macOS 26.5, Xcode 26.6 / Swift 6.3.3. Manual Activity Monitor comparisons were subsequently performed by the user on the same Mac.

| Check | Result | Actual observation |
| --- | --- | --- |
| Debug build with warnings as errors | PASS | `swift build -Xswiftc -warnings-as-errors` completed. |
| Release arm64 build with warnings as errors | PASS | `swift build -c release --arch arm64 -Xswiftc -warnings-as-errors` completed; `file` reported Mach-O 64-bit arm64. |
| XCTest | PASS | 9 tests executed, 0 failures. Includes formatter boundaries, live Mach sample, repeated reads, monitor lifecycle, and synthetic VM accounting. |
| Native diagnostic snapshot | PASS | `RamBar --memory-debug` printed one native Mach snapshot and exited without launching the menu-bar app. One snapshot: old 5,891,997,696 bytes (69%) vs revised 6,479,740,928 bytes (75%). |
| Installed launch | PASS | `./install.sh` built, signed, packaged, launched, and verified `~/Applications/RamBar.app`. |
| Status display / automatic refresh | PASS | Live menu-bar titles were observed updating normally after installation. |
| No Dock icon | PASS | The installed app was observed running as an LSUIElement with no RamBar Dock icon. |
| Single instance | PASS | Opening the installed bundle while it was running left exactly one verified installed RamBar process. |
| Refresh menu action | NOT TESTED | The menu action is wired to an immediate native sample; it was not manually clicked during final validation. |
| Activity Monitor comparison | PASS | Post-fix manual comparisons are documented below. Under a many-app workload, Activity Monitor implied 76.6% while RamBar showed 76%, a difference of about -0.6 percentage points. |
| Workload response | PASS | Manual validation with many applications open showed RamBar tracking Activity Monitor closely. |
| Sleep / wake | NOT TESTED | The wake observer is present; sleep was not tested during RamBar final validation. |
| Launch at Login | NOT TESTED | The persistent login-item setting was not changed during RamBar final validation. |
| Reinstall | PASS | Installation was run again after source changes and left one installed, running instance. |
| Uninstall | PASS | `./uninstall.sh` stopped the verified bundle, unregistered the login item, and removed only `~/Applications/RamBar.app`; a subsequent install succeeded. |
| CPU / RSS | PASS | `ps` observed RamBar at 0.0% CPU and 42,608 KiB RSS after several refresh cycles. |
| Child processes | PASS | `pgrep -P` found 0 children for the installed app. |
| Network inspection | PASS | `lsof -nP -a -p <RamBar PID> -i` returned 0 network endpoints. |
| Privacy manifest | PASS | Both source and installed manifests passed `plutil -lint`; `cmp` confirmed byte-identical copies. |
| Code signing | PASS | Installed bundle passed `codesign --verify --deep --strict`. |
| FreeBar isolation | PASS | RamBar was built in its own repository; no FreeBar files were modified. |

## Activity Monitor regression anchor

Confirmed manual observation before the accounting fix:

```text
Activity Monitor: 6.15 / 8.00 GB = 76.9%
Cached Files: 1.88 GB
RamBar before fix: 67%
Difference: -9.9 percentage points
```

The old formula counted only wired, non-purgeable internal, and physical compressor pages. It missed physical memory in page classes that are neither reclaimable cache nor represented by that narrow sum.

## Post-fix manual comparisons

### Observation A

```text
Physical Memory: 8.00 GB
Memory Used: 6.01 GB
Cached Files: 1.54 GB
Activity Monitor implied usage: 75.1%
RamBar: 72%
Difference: -3.1 percentage points
```

### Observation B — many applications open

```text
Physical Memory: 8.00 GB
Memory Used: 6.13 GB
Cached Files: 1.63 GB
Activity Monitor implied usage: 76.6%
RamBar: 76%
Difference: -0.6 percentage points
```

The second observation was intentionally taken with many applications open and validates that the revised accounting follows Activity Monitor closely under a real workload. Small differences are expected because the two values are sampled independently and macOS memory state changes continuously.

The revised formula is `physical - ((free - speculative) + external + purgeable) * pageSize`, defensively clamped to `0...physical`. `free_count` already includes speculative pages, so speculative is removed before external file-backed cache is included; compressor pages are implicit in the physical-minus-reclaimable result and are not added separately.

## Final status

The original ~10 percentage-point under-reporting defect is resolved. Core RAM accounting, native sampling, automatic refresh, installation, performance, privacy, and workload behavior are validated. Refresh-menu clicking, Launch at Login, and sleep/wake remain optional manual GUI checks rather than known defects.
