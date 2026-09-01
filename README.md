# Lid Awake

[Japanese](README.ja.md)

[![CI](https://github.com/ShimpeiTakeda/lid-awake/actions/workflows/ci.yml/badge.svg)](https://github.com/ShimpeiTakeda/lid-awake/actions/workflows/ci.yml)

Lid Awake is a focused macOS app that keeps an AC-powered MacBook running with its lid closed. It is designed for reaching ChatGPT/Codex on the Mac through ChatGPT Remote on an iPhone.

> [!WARNING]
> Lid Awake installs a root helper that changes `pmset -a disablesleep`. Never use it in a bag, on bedding, on a sofa, or anywhere that blocks ventilation. No signed and notarized binary is currently distributed.

## What it does

- **Normal Mode — green:** closing the lid uses the standard macOS sleep behavior.
- **Keeping Mac Awake — red:** the Mac continues running after the lid is closed.
- **Safety Stop — amber:** Lid Awake has restored Normal Mode after external power was disconnected or macOS reported serious thermal pressure.
- One large button starts and stops the mode. Lid Awake never restores Keep Awake mode automatically after a restart.

State names, descriptions, and icons accompany color so color is never the only signal.

## Why Lid Awake?

Lid Awake serves one narrow remote-access journey. It does not install agent hooks, infer whether an AI task is active, offer indefinite timers, or support battery-powered closed-lid operation. The tradeoff is deliberate: one explicit control, an AC-only policy, and automatic release when the app or its safety conditions disappear.

## Safety contract

- Keep Awake mode is allowed only while external power is connected.
- The GUI refreshes a `0600` lease every 10 seconds.
- Every 3 seconds, the helper rejects a lease that is older than 30 seconds, belongs to a dead or mismatched process, runs on battery power, or encounters a `serious` or `critical` macOS thermal state. It then runs `pmset -a disablesleep 0`.
- Helper startup, normal app termination, and uninstall all restore Normal Mode.
- Each `pmset` call has a five-second timeout. A transition succeeds only after `SleepDisabled` matches the requested state.
- Lid Awake does not bypass the lock screen, authentication, or FileVault.
- Lid Awake has no network client, telemetry, credential access, or access to ChatGPT conversation content.

See the [behavior contract](docs/BEHAVIOR_CONTRACT.md), [architecture](docs/ARCHITECTURE.md), and [threat model](docs/THREAT_MODEL.md).

## Requirements

- macOS 14 or later
- Apple Silicon MacBook
- Swift 6 and Xcode Command Line Tools for source builds
- External power while Keep Awake mode is active

Intel Macs are unsupported because the current CI and physical-device evidence cover Apple Silicon only.

## Build and test

```bash
git clone https://github.com/ShimpeiTakeda/lid-awake.git
cd lid-awake
./scripts/check.sh
open 'dist/Lid Awake.app'
```

The canonical check runs formatting, at least 40 unit and integration tests, a release build, ad-hoc code-signature verification, bundle and plist audits, localization completeness checks, and scans of publishable source files for secrets, local artifacts, and files larger than 1 MiB.

The first attempt to enable Keep Awake mode asks for administrator approval to install the helper. Before requesting approval, the app calculates SHA-256 digests for the helper and plist. The root process installs them only after copies in a root-owned staging directory match those digests.

## Languages

English is the fallback and canonical project language. The app follows the macOS language preference and currently includes complete English and Japanese UI resources. Repository policy and technical documentation are canonical in English; [README.ja.md](README.ja.md) is maintained as the Japanese entry point.

## Verification

Automated tests never change the root `pmset` state. Follow the [physical-device verification procedure](docs/VERIFICATION.md) for closed-lid operation and ChatGPT Remote from an iPhone. Evidence from an older commit is not evidence for a newer build. See the [test strategy](docs/TEST_STRATEGY.md) for the boundary between automated and physical-device evidence.

## Uninstall

Return Lid Awake to Normal Mode, quit the app, and run:

```bash
./scripts/uninstall-helper.sh
```

Then delete `dist/Lid Awake.app` or `/Applications/Lid Awake.app`.

## Limitations

- Lid Awake controls only macOS sleep blocking. Wi-Fi, internet access, OpenAI services, and the ChatGPT/Codex app are separate availability dependencies.
- After a restart with FileVault enabled, Remote cannot return before a local user logs in.
- A process that has already compromised the same logged-in user account cannot be fully prevented from forging a lease.
- Local builds are ad-hoc signed. No executable may be attached to a GitHub Release until Developer ID signing and notarization are complete.

The [release checklist](docs/RELEASE_CHECKLIST.md) deliberately separates source publication from binary distribution.

## Project policy

- [Contributing](CONTRIBUTING.md)
- [Security policy](SECURITY.md)
- [Code of Conduct](CODE_OF_CONDUCT.md)
- [Support](SUPPORT.md)
- [Governance](GOVERNANCE.md)
- [Changelog](CHANGELOG.md)

## Design reference

The closed-lid sleep mechanism and fail-safe approach were informed by the MIT-licensed [Adrafinil](https://github.com/kageroumado/adrafinil). Lid Awake is an independent implementation. It does not install AI-agent hooks or leave an unbounded persistent keep-awake setting.

## License

[MIT License](LICENSE)
