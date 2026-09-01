# Changelog

This project follows [Semantic Versioning](https://semver.org/).

## Unreleased

### Security

- Hardened lease and status I/O against symlink and path-replacement attacks.
- Restricted privileged status writes to an existing user-owned private directory.
- Bounded lease and status reads to regular files no larger than 64 KiB.

### Added

- Made English the fallback and canonical project language.
- Added complete English and Japanese app localization resources.
- Added tests for localization key completeness, format placeholders, app references, and fixed-width label budgets.

## 0.2.0 - 2026-09-01

### Security

- Staged the privileged helper in a root-owned temporary directory and verified its SHA-256 before changing system paths.
- Added a five-second `pmset` timeout and fail-safe termination.

### Tests

- Covered every lease rejection branch, time boundary, and failure precedence rule.
- Added sleep-transition, secure-file, process-timeout, and installer-injection tests.

## 0.1.1 - 2026-09-01

- Verified `SleepDisabled` after each `pmset` change and forced a safe retry after verification failure.

## 0.1.0 - 2026-09-01

- Added AC-only closed-lid operation, a 30-second lease, and thermal safety stops.
