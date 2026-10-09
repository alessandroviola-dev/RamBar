# v0.1.1 / build 2: local privacy checkpoint

No publication, push, tag, Actions run or installation is performed at this checkpoint.
The previous contaminated package is retained locally as evidence, not reused.

## Diagnosis

The old arm64 executable contained four personal-directory paths in Mach-O
`LC_SYMTAB` string data: linker-generated `OSO` records pointing to Swift object
files. Source `SO` records were already remapped to `/Source`. Swift reflection
sections were inspected; the observed private paths originated in the linker
debug map, not in the RAM calculation or runtime behavior.

`-debug-prefix-map` changes compiler debug paths but does not remap the linker's
object-file paths. The replacement uses supported Swift `-file-prefix-map` and
`-file-compilation-dir` options, a fresh scratch build, and Darwin ld `-S` to omit
STABS/DWARF debug information from the linked output. No signed binary is patched.
`nm -ap` confirms the new executable has no `OSO` or `SO` debug-map records.
The build may warn that no debug symbols remain; this is intentional for the
shipped executable, not a signing or runtime failure.

The original `unzip -p | grep ...` scans concatenated binary files and interprets
any nonzero pipeline result as absence. On the retained ZIP it returned producer
status 0 / grep status 1, despite direct executable scanning finding the paths.
This observed miss is not attributed to SIGPIPE: a separate early-exit `grep -q`
experiment returned producer status 141 / grep status 0, proving that `pipefail`
can also turn a detected match into the false branch. The new scanner uses
neither concatenation nor a producer/consumer pipeline.

## Correction

- `scripts/privacy-scan.py`: reads every regular bundle file as bytes, including
  Mach-O executables, and validates ZIP contents/CRC. Detects generic macOS and
  Linux personal directories, macOS per-user temporary directories, and HOME,
  including UTF-16 encodings; detection does not depend on HOME matching fixtures.
- Read/traversal/archive failures, missing/empty inputs and symlinks fail closed.
  Diagnostics never echo matched paths or filesystem exception paths.
- Packaging scans before signing and again in the ZIP and extracted bundle;
  strict signature and metadata checks are retained. Grep-based archive and
  dependency checks use saved files and distinguish absence from scan errors.
- Existing package output is refused, preserving prior evidence.
- The existing release workflow will run privacy regressions when used later;
  no workflow was triggered during this checkpoint.

## Local validation

- Privacy regressions: 10 tests PASS, including clean/contaminated bundle and ZIP,
  contaminated non-executable file, read errors, corrupt ZIP, symlink, UTF-16,
  and experimental SIGPIPE false-negative reproduction followed by scanner FAIL.
- Swift: 9 XCTest tests PASS, including corrected RAM accounting regressions.
- Installer: all 15 sandbox scenarios PASS, including rollback and simulated
  login-item unregister failure. No real Login Item setting is changed.
- Fresh isolated release build: arm64 PASS.
- Bundle identifier: `com.alessandroviola.rambar`; version/build: `0.1.1` / `2`.
- Plist lint, codesign deep/strict, ZIP extraction, privacy scans and archive
  byte-for-byte content comparison: PASS.
- Bash syntax and `git diff --check`: PASS.
- RAM source/tests, app functionality and operational installer unchanged.

The package is ad-hoc signed, not Developer ID notarized. Real GUI login-item
approval and reboot behavior remain outside the sandbox validation scope.
