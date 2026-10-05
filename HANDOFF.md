# Forge development handoff

This is the public source edition of Forge, a local-first SwiftUI gym tracker for iOS 17+. It uses English, kilograms, and Sunday-first weeks. Its editable weekly template follows Push/Pull/Legs/Upper/Lower with two rest days.

## Current state

Version 0.0.2 matches Android's template-population change at commit `b10917e7fb116f8ad047e04fd2e8dd0714a4f611`. Draft type selection appends missing saved targets, preserves logged work, and prevents duplicates. The session weekday takes priority when a type appears on multiple days, then the first Sunday-ordered matching day, then built-in defaults. Empty saved templates remain empty. Finished sessions only change their type label.

Program rest durations and persistent session timer deadlines are supported. New optional Codable fields keep old iOS schema-1 backups readable. All 27 core tests pass; Apple SDK compilation and on-device checks remain outstanding.

Implemented screens: Overview, Sessions, Program, and Settings. Logging supports exercises, weights/reps/sets, completion, warm-ups, notes, previous recorded weights, rest timing, and session editing/deletion. Charts cover top weight, estimated 1RM, volume, and training maxima.

The public repository contains fictional sample notes and a matching seed, not personal training records. Every imported example starts with Review needed. Dates and ambiguous notation must be checked before calendar totals include imported entries. Use local backup restore for personal data.

Core logic was tested on Linux with Swift 6.0.3. SwiftUI sources were syntax-parsed. An Apple SDK build, native UI type check, simulator/device checks, and signing remain outstanding. See VALIDATION.md for evidence and README.md for commands.

## Code map

- `Forge/ForgeApp.swift`: app entry point and tabs.
- `Forge/AppStore.swift`: application state, seed loading, session/program actions, and backup handling.
- `Forge/Core/Models.swift`: models, defaults, validation, Sunday calendar, and analytics.
- `Forge/Core/Training.swift`: saved-template resolution, fresh session creation, previous working weights, and non-destructive draft population.
- `Forge/Core/HistoryImporter.swift`: conservative note parsing and exercise aliases.
- `Forge/Core/ArchiveStorage.swift`: atomic persistence and previous-revision recovery.
- `Forge/Views`: native screens and logging controls.
- `Tests/ForgeCoreTests`: shared XCTest suite and fictional fixture.
- `scripts`: project generation, project checks, and fictional seed generation.

There are no external dependencies or application networking. The app target compiles the core directly; SwiftPM exposes the same files as ForgeCore. The shared scheme is Forge. Generate project references after adding/removing sources using `python3 scripts/generate_project.py`.

## Next steps

1. Build with Xcode 16+ on a Mac and resolve any Apple SDK/type-checking issues.
2. Run the iOS XCTest target and verify offline launch, session logging, persistence, calendar totals, overrides, backup/restore, and deletion.
3. Check number-pad input, chart interaction, small-screen layouts, large text, and VoiceOver.
4. For device installation, configure the user’s Apple development team and a unique bundle identifier.

Keep personal notes, exports, signing files, credentials, caches, and Xcode user data outside public Git history.
