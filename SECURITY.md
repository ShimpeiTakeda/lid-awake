# Security Policy

## Supported versions

Only the latest `main` revision is supported. No officially signed and notarized binary is currently distributed. Binaries redistributed by third parties are unsupported.

## Reporting a vulnerability

During private review, contact the repository owner through a private channel. After publication, use a [GitHub Security Advisory](https://github.com/ShimpeiTakeda/lid-awake/security/advisories/new). Do not publish reproduction steps or unresolved vulnerability details in an issue, discussion, or social-media post.

Include the affected commit, macOS version, Mac model and chip, reproduction steps, expected result, actual result, and impact. Do not attach tokens, cookies, personal information, device names, or ChatGPT conversation content.

## Privilege boundary

Lid Awake installs a root LaunchDaemon because changing `pmset -a disablesleep` requires elevated privileges. The helper executes only the fixed `/usr/bin/pmset` binary. During installation, it copies the helper and plist into a root-owned staging directory and compares them with SHA-256 digests calculated before administrator approval. System paths are changed only after both copies match.

See the [threat model](docs/THREAT_MODEL.md) and [release checklist](docs/RELEASE_CHECKLIST.md) for residual risks and distribution gates.
