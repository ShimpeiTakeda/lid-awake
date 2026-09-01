# Architecture

## Purpose

Lid Awake provides a single-window, one-button control for keeping a MacBook running with its lid closed. Keep Awake mode is limited to the GUI app's lifetime and must not leave a persistent system setting behind.

## Components

1. `LidAwakeApp`
   - A single SwiftUI window.
   - Refreshes a `0600` lease every 10 seconds.
   - Displays the red active state only after reading a verified helper status.
   - Uses English as the fallback UI language and ships complete English and Japanese resources.
2. `LidAwakeHelper`
   - A root LaunchDaemon.
   - Evaluates the lease, owner PID, AC power, and thermal state every three seconds.
   - Runs `pmset -a disablesleep 1|0` only when the desired state changes or the previous transition failed.
   - Applies a five-second timeout and accepts success only when the observed system state matches.
3. `LidAwakeShared`
   - Owns lease and status models, pure safety policy, transition tracking, secure JSON files, process execution, and installer command construction.

## State ownership

- `status.json`, written by the helper, is the source of truth for the GUI state.
- `lease.json`, refreshed by the GUI, is the source of truth for the user's active request.
- macOS `pmset` is the source of truth for actual sleep blocking.
- Verification reads `SleepDisabled` from `pmset -g`. `pmset -g custom` is not used because it does not expose that value.
- A GUI-local Boolean is never sufficient to claim that Keep Awake mode is active.

## Failure modes

| Failure | Response |
|---|---|
| Normal app termination | Write a disabled lease; the helper releases sleep blocking |
| Force quit or crash | Expire the lease after 30 seconds; the helper releases sleep blocking |
| External power disconnect | Release within the three-second helper polling interval |
| `serious` or `critical` thermal state | Release within the three-second helper polling interval |
| Helper restart | Release immediately, then reevaluate only a fresh lease |
| Mac restart | Reject the old lease because its owner is absent; remain in Normal Mode |
| Stale status | Stop displaying the red active state and show an error |
| `pmset` apply or verification failure | Forget the applied state so the next safe transition must retry `disablesleep 0` |
| `pmset` does not exit within five seconds | Terminate the process and follow the same safe-retry path |

## Privileged installation

Before requesting administrator approval, the GUI calculates SHA-256 digests for the helper and LaunchDaemon plist embedded in the app bundle. The root shell copies both files into a root-owned `/var/tmp/lid-awake-install.*` directory and verifies their digests before stopping the existing helper or changing `/Library` paths. It removes each staged file and the staging directory after success, failure, or a handled signal.

This design narrows the time-of-check/time-of-use risk from a user-writable source path. It does not replace Apple's `SMAppService` or code-signing-requirement-based caller verification. The [release checklist](RELEASE_CHECKLIST.md) is authoritative for binary distribution work.

When a release changes the helper safety contract, it increments the helper status schema. A new GUI then rejects old helper status and requests an administrator-authorized reinstall on the next start attempt.

## Localization ownership

- `Resources/en.lproj/Localizable.strings` is the fallback and canonical UI copy.
- `Resources/ja.lproj/Localizable.strings` is the Japanese translation.
- Both files must have identical keys and format placeholders.
- Repository policy and technical documentation are canonical in English. `README.ja.md` is the Japanese entry point, not a second technical source of truth.

## Non-goals

- Wi-Fi or OpenAI service availability
- FileVault login automation
- App Store distribution
- Binary distribution before Developer ID signing and notarization
- Automatic login or lock-screen bypass
- Closed-lid operation on battery power
