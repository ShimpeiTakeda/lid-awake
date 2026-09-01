# Threat Model

## Scope

Lid Awake blocks closed-lid sleep only while a logged-in user explicitly enables it on an AC-powered MacBook. It does not change macOS authentication, the lock screen, FileVault, networking, ChatGPT authentication, or service availability.

## Assets

- Reliable restoration of the normal macOS sleep setting
- A root helper restricted to fixed operations
- Equality between the helper verified during installation and the helper installed on disk
- Lease and status files that other user accounts cannot modify
- No collection of credentials, conversation content, or telemetry

## Trust boundaries

| Boundary | Trusted | Rejected or untrusted |
|---|---|---|
| GUI to lease | Logged-in user and a `0600` regular file | Stale, malformed, future-dated, or incorrectly owned lease |
| Helper to owner process | Live PID and `LidAwakeApp` executable path | PID reuse and a different executable |
| Installation | SHA-256 calculated by the running app and root-owned staging | A user-writable source path after administrator approval |
| Helper to macOS | Absolute `/usr/bin/pmset` path | PATH lookup, arbitrary commands, and unbounded execution |

## Threats and mitigations

| Threat | Mitigation | Residual risk |
|---|---|---|
| Sleep blocking remains after an app crash | 10-second heartbeat, 30-second expiry, owner PID validation | A stopped root helper cannot execute the release command |
| External power disconnect or thermal pressure | Independent three-second helper evaluation and `disablesleep 0` | OS or hardware fails to report the condition |
| Helper replacement during install | Copy to root staging and verify SHA-256 before install | The already-running GUI process is compromised |
| Shell injection | POSIX path quoting, lowercase-hex digest validation, fixed commands | AppleScript shell elevation remains a complex boundary |
| `pmset` hangs | Five-second timeout, then TERM and KILL if required | As with a helper crash, the last OS setting may remain |
| Forged lease | Regular-file, owner UID, `0600`, schema, freshness, PID, and path checks | A process that already controls the same user account cannot be fully excluded |
| Root helper follows a user-controlled status path | The helper requires an existing user-owned private directory, rejects symlinks, and uses descriptor-relative `openat` / `renameat` writes | The logged-in user controls status contents, which the helper never trusts as input |
| Symlink or oversized JSON input | `O_NOFOLLOW`, regular-file checks, and a 64 KiB read limit | A same-user process can still cause the UI to reject status and show a safe inactive state |
| Fake binary distribution | Do not distribute an official binary yet | A user may trust an unrelated third-party binary |
| Translation changes a safety instruction | English fallback, exact key and placeholder parity, label budgets, English canonical docs | A semantically poor translation can still pass structural tests |

## Public source and binary distribution

Publishing source code and safely distributing an executable are separate decisions. The source repository can be published after CI, policy, license, security documentation, localization, and owner review gates pass. A binary cannot be released until Developer ID signing, hardened runtime, notarization, stapling, and clean-machine install and uninstall tests are complete.

## Security regression gate

Re-review this threat model for any change to:

- helper privileges, installation method, or LaunchDaemon plist
- lease or status schema, owner validation, or permissions
- `pmset` invocation, timeout, or signal handling
- localization of safety and recovery instructions
- network access, telemetry, or automatic updates
- signing, notarization, or release workflow
