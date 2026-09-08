# RamBar verification

All results below were performed on the development Mac: Apple Silicon arm64, macOS 26.5, Xcode 26.6 / Swift 6.3.3.

| Check | Result | Actual observation |
| --- | --- | --- |
| Debug build with warnings as errors | PASS | `swift build -Xswiftc -warnings-as-errors` completed. |
| Release arm64 build with warnings as errors | PASS | `swift build -c release --arch arm64 -Xswiftc -warnings-as-errors` completed; `file` reported Mach-O 64-bit arm64. |
| XCTest | PASS | 5 tests executed, 0 failures. Includes formatter boundaries, clamping, live Mach sample, repeated reads, and monitor start/stop/start. |
| Live memory sample | PASS | XCTest read nonzero physical memory and a normalized percentage in `0...100`. |
| Installed launch | PASS | `./install.sh` built, signed, packaged, launched, and verified `~/Applications/RamBar.app`. |
| Status display / automatic refresh | PASS | The live menu-bar title was observed as `RAM 68%`, then `RAM 66%`, then `RAM 67%` across screen observations. |
| No Dock icon | PASS | The installed app was observed running as an LSUIElement with no RamBar Dock icon. |
| Single instance | PASS | Opening the installed bundle while it was running left exactly one verified installed RamBar process. |
| Refresh menu action | NOT TESTED | The menu action is wired to an immediate native sample; it was not clicked through GUI automation. |
| Activity Monitor comparison | NOT TESTED | Activity Monitor was opened and RamBar was visible in its process list, but its Memory pane was not safely automated for a same-moment numeric comparison. No comparison is claimed. |
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

## Activity Monitor notes

No Activity Monitor percentage is recorded because a same-time Memory Used value was not obtained. RamBar's formula is intentionally documented as an estimate: wired pages + non-purgeable internal pages + physical compressor pages, divided by `ProcessInfo.processInfo.physicalMemory`. File-backed external pages are not included as used memory, and compressor pages are counted once.
