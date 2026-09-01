# Release Checklist

## Source repository publication gate

- [x] Declare the MIT License
- [x] Document purpose, privileges, safety conditions, limitations, build, and uninstall steps
- [x] Provide a Security Policy, contribution guide, Code of Conduct, and changelog
- [x] Publish the threat model and residual risks
- [x] Run CI with minimal workflow permissions and a commit-pinned action
- [x] Test every safety-policy branch, boundary time, file permission, timeout, and installer command
- [x] Audit the built bundle ID, plists, code signature, localization resources, and exact file inventory
- [x] Audit publishable files for secret patterns, local artifacts, and files larger than 1 MiB
- [x] Make English the canonical repository and fallback app language
- [x] Keep complete, key-matched English and Japanese app resources
- [ ] Owner reviews the private repository source diff
- [ ] Owner reviews the final GitHub presentation and settings immediately before publication

The final two items are intentionally open for owner review. The repository must remain private until they are complete.

## Binary release gate

- [ ] Provision an Apple Developer Program distribution identity
- [ ] Sign the app and helper with Developer ID Application
- [ ] Finalize hardened runtime and minimum entitlements
- [ ] Complete Apple notarization and staple the ticket
- [ ] Test install, update, and uninstall on a clean supported macOS environment
- [ ] Verify power disconnect, app kill, helper restart, and thermal safety stop with the distribution build
- [ ] Document checksums and signature verification in the release notes

No executable may be attached to a GitHub Release until every binary gate passes. Ad-hoc signatures are for local development only.
