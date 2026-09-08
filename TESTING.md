# RamBar verification

All results below were performed on the development Mac: Apple Silicon arm64, macOS 26.5, Xcode 26.6 / Swift 6.3.3.

| Check | Result | Actual observation |
| --- | --- | --- |
| Debug build with warnings as errors | PASS | `swift build -Xswiftc -warnings-as-errors` completed. |
| Release arm64 build with warnings as errors | PASS | `swift build -c release --arch arm64 -Xswiftc -warnings-as-errors` completed; `file` reported Mach-O 64-bit arm64. |
| XCTest | PASS | 9 tests executed, 0 failures. Includes formatter boundaries, live Mach sample, repeated reads, monitor lifecycle, and synthetic VM accounting. |
| Native diagnostic snapshot | PASS | `RamBar --memory-debug` printed one native Mach snapshot and exited without launching the menu-bar app. One snapshot: old 5,891,997,696 bytes (69%) vs revised 6,479,740,928 bytes (75%). |
| Installed launch | PASS | `./install.sh` built, signed, packaged, launched, and verified `~/Applications/RamBar.app`. |
| Status display / automatic refresh | PASS | Live menu-bar titles observed: `RAM 68%`, `RAM 66%`, `RAM 67%`, then `RAM 63%` during the accounting investigation. |
| No Dock icon | PASS | The installed app was observed running as an LSUIElement with no RamBar Dock icon. |
| Single instance | PASS | Opening the installed bundle while it was running left exactly one verified installed RamBar process. |
| Refresh menu action | NOT TESTED | The menu action is wired to an immediate native sample; it was not clicked through GUI automation. |
| Activity Monitor comparison | PENDING MANUAL | See regression anchor and post-fix slot below. |
| Workload response | NOT TESTED | No artificial allocation was run; the Mac was already in active use. |
| Sleep / wake | NOT TESTED | The wake observer is present; sleep was not automated. |
| Launch at Login | NOT TESTED | The persistent login-item setting was not changed during verification. |
| Reinstall | PASS | Installation was run again after source changes and left one installed, running instance. |
| Uninstall | PASS | `./uninstall.sh` stopped the verified bundle, unregistered the login item, and removed only `~/Applications/RamBar.app`; a subsequent install succeeded. |
| CPU / RSS | PASS | `ps` observed RamBar at 0.0% CPU and 42,608 KiB RSS after several refresh cycles. |
| Child processes | PASS | `pgrep -P` found 0 children for the installed app. |
| Network inspection | PASS | `lsof -nP -a -p <RamBar PID> -i` returned 0 network endpoints. |
| Privacy manifest | PASS | Both source and installed manifests passed `plutil -lint`; `cmp` confirmed byte-identical copies. |
| Code signing | PASS | Installed bundle passed `codesign --verify --deep --strict`. |
| FreeBar isolation | PASS | RamBar was built in its own repository; no FreeBar files were modified. |

## Activity Monitor regression anchor

Confirmed manual observation before this fix:

```text
Activity Monitor: 6.15 / 8.00 GB = 76.9%
Cached Files: 1.88 GB
RamBar before fix: 67%
Difference: -9.9 percentage points
```

The old formula counted only wired, non-purgeable internal, and physical compressor pages. It missed physical memory in page classes that are neither reclaimable cache nor represented by that narrow sum.

## Post-fix manual comparison (pending)

```text
Physical Memory: pending
Memory Used: pending
Cached Files: pending
RamBar: pending
Difference: pending
```

The revised formula is `physical - ((free - speculative) + external + purgeable) * pageSize`, defensively clamped to `0...physical`. `free_count` already includes speculative pages, so speculative is removed before external file-backed cache is included; compressor pages are implicit in the physical-minus-reclaimable result and are not added separately.
