# Test Strategy

## Principle

Tests prioritize reliable release when conditions fail, not only successful activation. CI never changes the root system sleep setting. Pure policy, file-system behavior, subprocess behavior, localization, build artifacts, and physical-device journeys are separate evidence layers.

## Automated tests

| Layer | Coverage | Hard failure |
|---|---|---|
| Policy | Lease presence, schema, enabled flag, time boundaries, PID, path, AC power, thermal state, precedence | An unsafe input returns `.active` |
| Transition | Unknown startup state, successful state, retry after apply failure | A safe release is skipped after failure |
| Parser | `pmset -g` values 0 and 1, missing key, invalid value, similar key | Actual state is misidentified |
| File | JSON round trip, `0700`/`0600`, atomic replacement, malformed JSON | Permissions weaken, a temporary file remains, or malformed state is accepted |
| Process | stdout, stderr, exit status, large output, timeout, invalid timeout | The helper thread can block indefinitely |
| Installer | Path quoting, digest validation, root-staging order, shell syntax | A system path changes before artifact verification |
| Localization | Identical key sets, placeholders, app references, English fallback, fixed-window label budgets | Missing copy, fallback drift, or probable truncation |
| Artifact | Bundle ID, minimum OS, language inventory, helper plist, code signature, exact file inventory | Identifier mismatch, missing language, unexpected file, or broken signature |
| Source | Formatting, shell syntax, secret patterns, local artifacts, files over 1 MiB, canonical-language boundary | Private data, generated output, or noncanonical project text enters publication scope |

The canonical command is:

```bash
./scripts/check.sh
```

## Physical-device tests

Use the [physical-device verification procedure](VERIFICATION.md) for the root helper and closed-lid behavior. Evidence belongs to the exact tested commit and cannot be carried forward. CI does not replace:

- fresh install and update with administrator approval
- external-power disconnect, app kill, and helper restart
- ChatGPT Remote from an iPhone on a separate network while the lid is closed
- Gatekeeper verification of a signed and notarized distribution build
- visual inspection in both English and Japanese

## Interpreting coverage

Line coverage alone is not the quality gate. Every root privilege boundary and failure mode must identify whether automated or physical-device evidence covers it. Passing unit tests never upgrades an unperformed physical-device scenario to covered.
