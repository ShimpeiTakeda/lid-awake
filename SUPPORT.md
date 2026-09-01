# Support

## Before opening an issue

1. Return Lid Awake to Normal Mode.
2. Run `pmset -g | grep SleepDisabled` and confirm whether the value is `0` or `1`.
3. Run `./scripts/check.sh` from the exact commit you are testing.
4. Read the [limitations](README.md#limitations), [physical-device verification procedure](docs/VERIFICATION.md), and existing issues.

Use the bug-report form for reproducible defects and the feature-request form for proposed behavior. Include the commit, macOS version, Mac chip, external-power state, exact steps, and result. Do not include credentials, device names, user names, or ChatGPT conversation content.

Security vulnerabilities must follow [SECURITY.md](SECURITY.md), not a public issue.

## Scope

Support covers the source on the latest `main` revision. Third-party binaries, unsupported macOS versions, Intel Macs, network failures, OpenAI service failures, and ChatGPT account issues are outside this project's support boundary.

This volunteer project provides no response-time or availability SLA.
