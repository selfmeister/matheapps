# MathPilot release preparation — 2026-10-26

Prepared version **1.0 (build 2)**, bundle ID `com.mathpilot.app`.

## Completed

- Corrected the local English and German App Store listing: both keyword fields are 96 ASCII bytes; promotional text is 165 characters. Replaced the misleading “no analytics” claim with explicit on-device learning statistics and no third-party analytics.
- Verified the existing App Store Connect API key with read-only requests. The app is in `PREPARE_FOR_SUBMISSION`, version 1.0; no builds were uploaded at the time of checking.
- Fixed `../ship.sh` to pass API credentials to both archive and export via Xcode command-line flags. Added an optional `BUILD_NUMBER` override and verified compatibility with macOS Bash. Script regression tests use a fake xcodebuild and never upload.
- Built a fresh signed Release archive, exported the App Store IPA, and verified the archive signature against the system trust store.
- Ran four tests on each of iPhone 17 Pro and iPad Pro 13-inch (M5), iOS 26.5, with zero failures. The integration test covers all four arithmetic operations, an incorrect answer, retries, duplicate taps, five-task completion, result counts, persistence and starting another round. UI tests cover English/German feedback, worked examples, starting practice, language switching, empty history and relaunch persistence.
- Visually inspected English/German feedback screenshots on both device sizes and German practice screenshots on both sizes.

## Local artifacts

Artifacts are in the git-ignored `build/release-20261026/` directory:

- `MathPilot.xcarchive` — signed release archive.
- `export/MathPilot.ipa` — distributable IPA.
- `SHA256.txt` — IPA checksum.
- `logs/` — archive, export and iPhone/iPad test logs.
- `screenshots/iphone/` and `screenshots/ipad/` — feedback and practice screenshots in English and German.
- `source-hashes.json` — source/configuration hashes corresponding to this release preparation.

## Scope and remaining release actions

The simulator tests compile the actual app source in an isolated test app with a separate bundle ID and seeded history. Fixture code is not included in the shipping target. The signed production archive is built separately from the real MathPilot target.

No physical-device test was performed. No build, screenshots or listing edits were uploaded to App Store Connect, and no review submission was made. The listing fixes are in `../APPSTORE_LISTING.md`. App Store Connect's remaining submission fields and screenshots still need final review when preparing the submission.

`../ship.sh` uploads when run; do not use it as a local-only validation command.
