# Changelog (audichuang fork)

Fork-only changes. Upstream history lives in CHANGELOG.md.

## 0.82.0.1 - audi.1

### Fixed

- iCloud fleet: explicitly send stalled Mac snapshot saves with rate-limited retries and persistent diagnostics.
- iCloud fleet: clear the send kick backoff deadline after a successful push, so a later stall is not held back by a stale kick backoff.
