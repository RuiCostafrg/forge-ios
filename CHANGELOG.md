# Changelog

## 0.0.2 — 5 October 2026

Port the saved-template session behavior from Forge Android 0.0.2 (`b10917e7fb116f8ad047e04fd2e8dd0714a4f611`).

- Start any workout type using its saved template, including on a different day.
- Prefer the session's own weekday when a type repeats; otherwise choose the first saved matching day in Sunday-first order.
- Use built-in targets for types without a saved template, while preserving deliberately empty saved templates.
- Selecting a draft's type adds missing exercises without duplicating targets or changing logged sets, notes, and exercise order.
- Finished sessions change their type without modifying their exercises.
- New sets have fresh IDs and incomplete status, with previous confirmed working weights when available.
- Save program rest durations and persist rest timer deadlines. Completing a set starts the timer; undoing completion cancels it.
- Keep older iOS backups compatible through optional metadata fields.
- Add 13 regression tests; all 27 core tests pass.

Apple SDK compilation, simulator/device checks, and signing still require Xcode. This update is source code, not a signed IPA release.
