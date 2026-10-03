# Forge — local iPhone gym tracker

A native SwiftUI gym tracker for iOS 17+. Track weights, repetitions, sets, and notes with an editable Push/Pull/Legs/Upper/Lower weekly program. The interface is English, weights are in kilograms, and weeks start on Sunday.

## Run the app

Open **Forge.xcodeproj** in Xcode 16 or newer on a Mac, select the **Forge** scheme, choose an iPhone simulator, and click Run. There are no external packages, accounts, servers, or API keys.

For your own iPhone, select your development team in Signing & Capabilities, choose a unique app bundle identifier, connect your phone, and run the app. Enable Developer Mode and trust the development profile if iOS asks. Personal-team builds may need periodic re-signing.

This project was prepared in a Linux cloud workspace. Its Foundation core is tested and its Swift source syntax is checked. Native SwiftUI type checking, Apple SDK compilation, simulator testing, and signing still need Xcode on a Mac. No signed `.ipa` is included.

## Features

- **Overview:** today’s workout suggestion, workout overrides, Sunday-first weekly activity, working-set/volume totals, recent sessions, and interactive strength charts.
- **Sessions:** Sunday-first monthly calendar, session dates, search, history/review/draft filters, editing, and deletion.
- **Logging:** previous recorded weights, exercises, reps/sets/kg, completion checks, warm-up flags, set/exercise/session notes, training maxima, and a rest timer.
- **Program:** independently editable days, exercise templates, set counts, rep targets, and rest/custom workouts.
- **Settings:** local backup export/restore, previous-revision recovery, and source-note review.

The starting schedule is Sunday Push, Monday Pull, Tuesday Legs, Wednesday Rest, Thursday Upper, Friday Lower, Saturday Rest. Change any day in Program or choose any workout when starting a session.

Session edits save automatically. **Done** closes the editor and preserves an unfinished session as a draft. **Finish session** marks a workout complete after a working set is recorded. Tap a set number to edit its note or warm-up status. Changing a session’s type preserves its exercises.

## Sample data and personal history

The bundled training notes and seed contain **six fictional example entries**, clearly labelled in `Forge/Resources/TrainingHistory.md`. This public repository contains no personal training history or private session handoff.

Load your own local Forge JSON backup using **Settings → Restore backup**. Personal backups belong on your phone or in a private storage location. The app itself does not sync them to GitHub.

The historical parser supports explicit `8x44` and `3x5x120` notation, decimal commas, common exercise aliases, and separate 5/3/1 training maxima. It preserves incomplete/unclear notation in the original notes. Years are never inferred from partial dates. Imported entries initially need review; confirm their dates and sets before including them in calendar totals.

The chart toggle for imported history shows note order followed by new sessions, rather than assuming a calendar timeline. Rename exercise variants to combine their progress under the same exercise name.

## Metrics

Volume is completed working-set external load × repetitions. Warm-ups and incomplete sets are excluded. Estimated 1RM uses the Epley formula for working sets of 1–12 reps; a single rep uses the recorded weight. Training maxima are separate from weights actually lifted. Bodyweight sets contribute zero external load to volume.

## Local storage

There is no backend, telemetry, third-party SDK, or application networking. Data lives in Application Support as `Forge/forge.json`. Saves validate the archive and write atomically, retaining the previous valid revision in `forge.previous.json`. iOS file protection is enabled until the first unlock after restarting the phone.

Export from Settings and choose **On My iPhone** in Files for a local backup. Restore validates the file before replacing data. A damaged startup store is preserved and can be recovered from a previous revision or backup. iOS device backups and selected Files destinations follow the phone’s settings. Export before uninstalling the app or changing its bundle identifier.

## Tests and project maintenance

The shared Foundation core has 14 XCTest tests, runnable through SwiftPM on macOS/Linux and through the Xcode **ForgeTests** target:

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

See `VALIDATION.md` for what has and has not been checked. Before regular use, verify offline launch, session persistence after force quitting, workout overrides, calendar dates, backup/restore, and deletion on a simulator or phone. Check small-screen, large-text, and VoiceOver behaviour.

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

The seed is imported once per installation. Existing saved data is retained across app updates. Backup schema version is 1; Codable dates preserve Foundation’s native precision.
