# Forge — local iPhone gym tracker

A native SwiftUI gym tracker for iOS 17+. Track weights, repetitions, sets, and notes with an editable Push/Pull/Legs/Upper/Lower weekly program. The interface is English, weights are in kilograms, and weeks start on Sunday.

Version **0.0.3** adds history-based 5/3/1 prescriptions and local Markdown history import. It retains the saved-template behavior ported the saved-template population behavior from [Forge Android 0.0.2](https://github.com/RuiCostafrg/forge-android/commit/b10917e7fb116f8ad047e04fd2e8dd0714a4f611).

## Run the app

Open **Forge.xcodeproj** in Xcode 16 or newer on a Mac, select the **Forge** scheme, choose an iPhone simulator, and click Run. There are no external packages, accounts, servers, or API keys.

For your own iPhone, select your development team in Signing & Capabilities, choose a unique app bundle identifier, connect your phone, and run the app. Enable Developer Mode and trust the development profile if iOS asks. Personal-team builds may need periodic re-signing.

The 43 Foundation core tests pass on Linux and macOS. The SwiftUI app and XCTest target compile successfully with Xcode 16.4 for the iOS Simulator in [GitHub Actions](https://github.com/RuiCostafrg/forge-ios/actions/runs/37496358100). Simulator interaction, device execution, and signing still need validation. No signed `.ipa` is included.

## Features

- **Overview:** today’s workout suggestion, workout overrides, Sunday-first weekly activity, working-set/volume totals, recent sessions, and interactive strength charts.
- **Sessions:** Sunday-first monthly calendar, session dates, search, history/review/draft filters, editing, and deletion.
- **Logging:** previous recorded weights, exercises, reps/sets/kg, completion checks, warm-up flags, set/exercise/session notes, training maxima, and a persistent rest timer.
- **Program:** independently editable days, exercise templates, set counts, rep targets, rest durations, and rest/custom workouts.
- **Settings:** local backup export/restore, previous-revision recovery, and source-note review.

The starting schedule is Sunday Push, Monday Pull, Tuesday Legs, Wednesday Rest, Thursday Upper, Friday Lower, Saturday Rest. Change any day in Program or choose any workout when starting a session.

Session edits save automatically. **Done** closes the editor and preserves an unfinished session as a draft. **Finish session** marks a workout complete after a working set is recorded. Tap a set number to edit its note or warm-up status.

Selecting a draft's session type adds missing program exercises and set/rep targets while preserving existing exercise IDs, notes, and logged sets. Repeated selection does not duplicate exercises. **Add missing program exercises** also applies the current type without switching away and back. Finished sessions only change their type label; reopen a new completed session to populate it.

Templates resolve against the session's date: a matching day and type take priority, then the first saved day of that type in Sunday-first order. When no saved template exists, built-in targets are used. Deliberately empty saved templates remain empty. New sets have fresh IDs, start incomplete, and use previous working weights from confirmed completed sessions when available.

Starting a session copies the chosen template's rest duration. Program rest durations can be edited from 15 to 600 seconds. Completing a set starts the rest timer; undoing completion cancels it. Its deadline persists across closing/relaunching the app, without background notifications. Selecting another session type preserves that session's current rest settings and logged work.

## 5/3/1 suggestions

Bench press, overhead press, squat, and deadlift are recognised from their names and common aliases (BP, OHP, Squat, DL). When starting a session or adding a main lift, Forge uses that lift’s latest valid phase and training max (TM) to generate **three incomplete working sets**. It keeps the saved program’s accessory exercises. A main lift must be in the chosen template or added manually; unrelated press variations are not treated as a barbell main lift.

| Phase | Percentages of TM | Minimum reps |
| --- | --- | --- |
| 5/5/5 | 65%, 75%, 85% | 5, 5, 5+ |
| 3/3/3 | 70%, 80%, 90% | 3, 3, 3+ |
| 5/3/1 | 75%, 85%, 95% | 5, 3, 1+ |
| Optional deload | 40%, 50%, 60% | 5, 5, 5 |

The phases advance per lift, per completed exposure, rather than by calendar week. After 5/3/1, the next cycle adds the most recent positive TM change up to 10 kg found in that lift’s history. If none exists, the fallback is 2.5 kg for presses and 5 kg for squat/deadlift. A reset uses the latest TM, rather than the highest historical value. With deload enabled, the TM increases after the deload instead. Weights round to the nearest 2.5 kg by default; ties round up. Warm-ups, supplemental sets, and extra singles are not inferred from inconsistent logs and can be added manually. The + target means optional extra reps; the numeric target is the minimum.

An imported line such as `BP 5/5/5 100` is interpreted as **TM 100 kg**, not a lifted weight or a 1RM. Phase-only history can guide the next session without creating historical completed sets. Where later logged reps disagree with the phase label, the label determines the prescription. Suggestions show their source entry. Undated imports, including entries awaiting calendar review, use document order; years are never guessed. New Forge sessions take precedence over imported history and only advance a lift when finished with at least three completed working sets. Drafts, partial sessions, and known future-dated sessions are excluded.

Open **Program → day → exercise → 5/3/1 settings** to disable automatic detection for an accessory, set a fixed TM or phase, choose a cycle increase and rounding step, enable deloads, or exclude imported history. With no usable TM, ordinary program targets are kept. A fixed TM or phase remains fixed until changed. A new session stores its prescription as a snapshot, so reopening it or selecting another workout type preserves logged sets. In an unlogged session, adjust its 5/3/1 controls and tap **Recalculate 5/3/1 sets**; recalculation is disabled once any set is completed. Individual reps and weights always remain editable.

To prepare a private backup from notes on macOS/Linux, write the output outside this public checkout:

```sh
swiftc Forge/Core/*.swift scripts/PrepareHistory.swift -o /tmp/forge-history
/tmp/forge-history /path/to/T.md /private/path/Forge-history.json
```

## Sample data and personal history

The bundled training notes and seed contain **six fictional example entries**, clearly labelled in `Forge/Resources/TrainingHistory.md`. This public repository contains no personal training history or private session handoff.

Use **Settings → Import training notes (.md)** to append your own T.md history, or **Settings → Restore backup** for a Forge JSON backup. Markdown import previews the number of new entries and skips matching imported occurrences on repeat import. JSON restore replaces current data. Personal backups belong on your phone or in a private storage location. The app itself does not sync them to GitHub.

The historical parser supports explicit `8x44` and `3x5x120` notation, decimal commas, common exercise aliases, and separate 5/3/1 training maxima. It preserves incomplete/unclear notation in the original notes. Years are never inferred from partial dates. Imported entries initially need review; confirm their dates and sets before including them in calendar totals.

The chart toggle for imported history shows note order followed by new sessions, rather than assuming a calendar timeline. Rename exercise variants to combine their progress under the same exercise name.

## Metrics

Volume is completed working-set external load × repetitions. Warm-ups and incomplete sets are excluded. Estimated 1RM uses the Epley formula for working sets of 1–12 reps; a single rep uses the recorded weight. Training maxima are separate from weights actually lifted. Bodyweight sets contribute zero external load to volume.

## Local storage

There is no backend, telemetry, third-party SDK, or application networking. Data lives in Application Support as `Forge/forge.json`. Saves validate the archive and write atomically, retaining the previous valid revision in `forge.previous.json`. iOS file protection is enabled until the first unlock after restarting the phone.

Export from Settings and choose **On My iPhone** in Files for a local backup. Restore validates the file before replacing data. A damaged startup store is preserved and can be recovered from a previous revision or backup. iOS device backups and selected Files destinations follow the phone’s settings. Export before uninstalling the app or changing its bundle identifier.

## Tests and project maintenance

The shared Foundation core has 43 XCTest tests, runnable through SwiftPM on macOS/Linux and through the Xcode **ForgeTests** target:

```sh
swift test
python3 scripts/validate_project.py --swiftc swiftc

xcodebuild -project Forge.xcodeproj -scheme Forge \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build

# Substitute an installed simulator from xcrun simctl list devices available.
xcodebuild -project Forge.xcodeproj -scheme Forge \
  -destination 'platform=iOS Simulator,name=iPhone 16' test
```

GitHub Actions runs the core tests, project validator, and unsigned Apple SDK build of the app and XCTest target on macOS. See `VALIDATION.md` for what has and has not been checked. Before regular use, verify offline launch, session persistence after force quitting, workout overrides, calendar dates, backup/restore, and deletion on a simulator or phone. Check small-screen, large-text, and VoiceOver behaviour.

`Forge/Core` contains the shared model, parser, analytics, and storage. `Forge/Views` contains the SwiftUI screens. The checked-in project requires no XcodeGen. After adding/removing sources, regenerate it with:

```sh
python3 scripts/generate_project.py
```

To regenerate the bundled **fictional** seed after changing the sample or parser:

```sh
swiftc Forge/Core/*.swift scripts/SeedHistory.swift -o /tmp/forge-seed
/tmp/forge-seed
cp Forge/Resources/TrainingHistory.md Tests/ForgeCoreTests/Fixtures/TrainingHistory.md
```

The seed is imported once per installation. Existing saved data is retained across app updates. Backup schema version is 1; Codable dates preserve Foundation’s native precision. The optional template identity, rest duration, timer deadline, 5/3/1 controls, and prescription snapshot fields remain compatible with older iOS backups. Android and iOS backup formats remain different.
