# Contributing

## Change policy

Lid Awake preserves a deliberately small behavior contract: external power only, app-lifetime only, and one-button start and stop. Fail-safe behavior, privilege boundaries, and recovery take priority over feature growth.

Open an issue before implementation. Explain the purpose, user-visible effect, and impact on permissions or safety conditions. Never include credentials, device names, user names, or ChatGPT conversation content in issues or test fixtures.

## Development environment

- macOS 14 or later
- Swift 6
- Xcode Command Line Tools

```bash
git clone https://github.com/ShimpeiTakeda/lid-awake.git
cd lid-awake
./scripts/check.sh
```

## Language policy

English is canonical for code comments, test names, repository documentation, issue templates, and contributor communication. The app currently supports complete English and Japanese UI resources. Update both localization files in the same pull request; missing or mismatched keys fail CI.

## Pull request gate

- Explain any public API or user-visible behavior change in an agreed issue.
- Add both success and safe-recovery tests for every new or changed failure mode.
- Update the [threat model](docs/THREAT_MODEL.md) for changes to the root helper, installer, `pmset`, lease, status, or file permissions.
- Pass `./scripts/check.sh`.
- Claim physical-device verification only when it was performed on the exact commit and conditions documented in the pull request.
- Do not commit generated artifacts, signing material, credentials, local status files, or local lease files.

## Commits and releases

Do not mix unrelated changes in one commit. Only the maintainer may sign, notarize, or publish a release.
