# Validation status

The public edition replaces personal history with six fictional sample entries and corresponding test fixtures. No personal notes or private handoff are included.

The shared Foundation core has a 14-test XCTest suite covering Sunday week boundaries, program overrides, explicit set parsing, decimal commas, training-max separation, ambiguous notation, date handling, history ordering, previous weights, warm-up exclusion, progress metrics, sample import, JSON round trips, atomic storage, recovery, and invalid backup rejection.

On 3 October 2026, all **14 XCTest tests passed with zero failures** using Swift 6.0.3 on Linux. The complete run is recorded in `test-results.log`. The public sample contains six fictional entries, 12 exercises, and 36 explicit sets.

Project validation also passed for all 11 app Swift files and four resources, including source/resource references, target/scheme/workspace structure, plist/XML data, fictional seed/fixture equivalence, and Swift syntax. The public-content review excluded private training records, private session identifiers, and the original personal handoff.

An Apple SDK build, native SwiftUI type checking, iOS simulator/device execution, screenshots, and signing have not been performed in the Linux workspace. This is a source project, not a signed iPhone binary. Use the README commands and device checklist to perform the remaining native validation.
