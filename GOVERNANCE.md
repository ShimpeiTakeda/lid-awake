# Governance

Lid Awake is maintained by [@ShimpeiTakeda](https://github.com/ShimpeiTakeda). The maintainer owns release decisions, security response, scope, and the final interpretation of the behavior contract.

Contributions are evaluated against the following order of priority:

1. Fail-safe restoration of normal macOS sleep behavior
2. Minimum and auditable privilege
3. A predictable one-button user journey
4. Accessibility and localization parity
5. Additional features

Material changes to privileges, safety policy, or user-visible behavior require an issue before implementation. Maintainer approval does not override the binary release gates in [docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md).

The project may reject technically valid contributions that broaden scope, weaken the safety contract, add unnecessary network access, or create maintenance obligations disproportionate to the core use case.
