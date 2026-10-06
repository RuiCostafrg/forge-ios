# Changelog

## 0.0.3 — 6 October 2026

- Detect the four 5/3/1 main lifts from local phase/TM history when creating a session or adding an exercise.
- Suggest the next independent lift phase, standard percentage working sets, and weights rounded to a configurable increment.
- Infer the latest historical cycle increase, support resets, and allow fixed TM/phase, custom increase, optional deload, imported-history opt-out, and disabling suggestions.
- Show each prescription’s source and preserve it across draft reopening/type changes. Recalculate unlogged sets only; keep completed work intact.
- Import local Markdown training notes additively with a preview and occurrence-aware duplicate handling. Keep incomplete dates unresolved and source notes intact.
- Preserve legacy schema-1 backups through optional fields. Add 16 regression tests, bringing the suite to 43 passing tests.
- Add private backup preparation tooling and a macOS CI check for core tests and unsigned Apple SDK compilation.


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
