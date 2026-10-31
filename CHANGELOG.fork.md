# Changelog (audichuang fork)

Fork-only changes. Upstream history lives in CHANGELOG.md.

## Fork sync gate

`make fork-gate` (`Scripts/fork_sync_gate.sh`) is the one fail-fast check for upstream syncs and fork pushes. Each stage prints `PASS`/`FAIL` with its elapsed time; logs go to `~/Library/Caches/codexbar-gate/gate-<stage>.log`.

- Default (about 2 min warm): conflict markers, identity `--check` and README/signing/release-workflow guards, footprint budget, parser hash + xcodegen + localization, version, lint (no rule worse than the base tag plus `fork/lint-allowance.tsv`), `swift build`, fork-scoped `swift test`.
- `--quick`: same as default. `--ios`: also run CodexBarMobileTests. `--full`: also the whole Mac `swift test` and iOS tests (before a release).
- `--baseline <dir>`: Mac/iOS runs pass when no failing test is outside `<dir>/baseline-{mac,ios}-fail.txt`; without it they need zero failures.
- Pass flags through make: `make fork-gate ARGS='--ios --baseline ~/Library/Caches/codexbar-gate'`.
- `Scripts/fork/swift_scratch.sh` runs swift with the shared scratch path (`CODEXBAR_SWIFT_SCRATCH` overrides it).

## 0.82.0.1 - audi.2

### Fixed

- iCloud fleet: a Mac without local Claude credentials no longer hides the remote Claude account whose email matches its Codex login (upstream fix pending PR).

## 0.82.0.1 - audi.1

### Fixed

- iCloud fleet: explicitly send stalled Mac snapshot saves with rate-limited retries and persistent diagnostics.
- iCloud fleet: clear the send kick backoff deadline after a successful push, so a later stall is not held back by a stale kick backoff.
