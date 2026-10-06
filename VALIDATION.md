# Validation status

The public edition replaces personal history with six fictional sample entries and corresponding test fixtures. No personal notes or private handoff are included.

The shared Foundation core has a 43-test XCTest suite covering Sunday week boundaries, program overrides, explicit set parsing, decimal commas, training-max separation, ambiguous notation, date handling, history ordering, previous weights, warm-up exclusion, progress metrics, sample import, JSON round trips, atomic storage, recovery, and invalid backup rejection.

On 6 October 2026, all **43 XCTest tests passed with zero failures** using Swift 6.0.3 on Linux. The complete run is recorded in `test-results.log`. The public sample contains six fictional entries, 12 exercises, and 36 explicit sets.

The 13 new regressions cover off-schedule saved templates and rest durations, date-specific repeated types, Sunday-first fallback, absent-type built-in targets, empty saved targets, fresh IDs and previous weights, idempotent draft population, preserving notes/completed sets, renamed exercise identity, finished/rest/custom behavior, legacy backup decoding, and persistent rest deadlines.

Project validation also passed for all 15 app Swift files and both XCTest source files and four resources, including source/resource references, target/scheme/workspace structure, plist/XML data, fictional seed/fixture equivalence, and Swift syntax. Existing published source files were verified against GitHub before editing. Public data remains fictional.

The 16 new 5/3/1/import regressions cover percentage sets, phase metadata versus actual reps, document order, independent lifts, supplemental work exclusion, microloading, latest increases and resets, optional deloads, overrides and rounding, opt-outs and missing TMs, partial/draft/future-session exclusion, template/manual creation, snapshot preservation, JSON compatibility and validation, additive import, and repeated identical occurrences.

A macOS GitHub Actions workflow now runs core tests, project validation, and an unsigned Apple SDK build of both targets. Its first result is pending publication at the time of this local report.

An Apple SDK build, native SwiftUI type checking, iOS simulator/device execution, screenshots, and signing have not been performed in the Linux workspace. This is a source project, not a signed iPhone binary. Use the README commands and device checklist to perform the remaining native validation.
