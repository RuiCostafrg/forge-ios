import Foundation
import XCTest
#if SWIFT_PACKAGE
@testable import ForgeCore
#else
@testable import Forge
#endif

final class WendlerTests: XCTestCase {
    func date(_ text: String) -> Date { HistoryImporter.exactDate(text)! }
    func history(_ text: String) -> Archive { Archive(sessions: HistoryImporter.parse(text)) }
    func suggestion(_ name: String, _ archive: Archive) -> WendlerPrescription? {
        Wendler.suggest(for: Defaults.exercise(name), in: archive, date: date("06.10.26"))
    }
    func testThreePhasesUseStandardPercentagesAndPlusTargets() {
        let fives = WendlerPrescription(phase: .fives, trainingMax: 100, cycleIncrease: 2.5, rounding: 2.5, sourceLabel: "Test")
        XCTAssertEqual(fives.sets.map(\.weight), [65, 75, 85])
        XCTAssertEqual(fives.sets.map(\.reps), [5, 5, 5])
        XCTAssertTrue(fives.sets.last!.note.contains("5+"))
        XCTAssertTrue(fives.sets.allSatisfy { !$0.completed && !$0.warmup })
        var threes = fives; threes.phase = .threes
        XCTAssertEqual(threes.sets.map(\.weight), [70, 80, 90])
        XCTAssertEqual(threes.sets.map(\.reps), [3, 3, 3])
        var singles = fives; singles.phase = .singles
        XCTAssertEqual(singles.sets.map(\.weight), [75, 85, 95])
        XCTAssertEqual(singles.sets.map(\.reps), [5, 3, 1])
    }
    func testLatestPhaseMetadataWinsOverInconsistentActualReps() {
        let archive = history("BP 5/5/5 100\n——\nBP 3/3/3 100\n5x65 5x75 5x85")
        let next = suggestion("BP", archive)!
        XCTAssertEqual(next.phase, .singles)
        XCTAssertEqual(next.trainingMax, 100)
        XCTAssertTrue(next.usesImportedOrder)
        XCTAssertTrue(next.sourceLabel.contains("Imported entry 2"))
        XCTAssertEqual(next.sourceSessionID, archive.sessions.last!.id)
    }
    func testImportedDocumentOrderDoesNotSortTypoDatesOrInventYears() {
        let archive = history("31/12\nBP 5/5/5 100\n01/01\nBP 3/3/3 100")
        XCTAssertTrue(archive.sessions.allSatisfy { $0.date == nil && $0.needsReview })
        XCTAssertEqual(suggestion("Bench press", archive)?.phase, .singles)
    }
    func testLiftCyclesAdvanceIndependentlyAndIgnoreSupplementalWork() {
        let archive = history("BP 5/3/1 100\nOHP 5/5/5 50\n——\nSquat 3/3/3 150\n——\nDL 5/5/5 200\n——\nBP 3x5x80")
        XCTAssertEqual(suggestion("BP", archive)?.phase, .fives)
        XCTAssertEqual(suggestion("BP", archive)?.trainingMax, 102.5)
        XCTAssertEqual(suggestion("OHP", archive)?.phase, .threes)
        XCTAssertEqual(suggestion("Squat", archive)?.phase, .singles)
        XCTAssertEqual(suggestion("DL", archive)?.phase, .threes)
        XCTAssertNil(suggestion("Incline bench press", archive))
    }
    func testHistoricalMicroIncreaseAndLatestResetAreRespected() {
        let archive = history("BP 5/3/1 120\n——\nBP 5/5/5 121.25\n——\nBP 5/3/1 121.25\n——\nBP 5/5/5 100\n——\nBP 5/3/1 100")
        let next = suggestion("BP", archive)!
        XCTAssertEqual(next.cycleIncrease, 1.25)
        XCTAssertEqual(next.trainingMax, 101.25)
        XCTAssertEqual(next.phase, .fives)
    }
    func testLatestIncreaseIsUsedRatherThanAnOldLargerIncrease() {
        let archive = history("Squat 5/3/1 180\n——\nSquat 5/5/5 182.5\n——\nSquat 5/5/5 183.75\n——\nSquat 5/3/1 183.75")
        XCTAssertEqual(suggestion("Squat", archive)?.cycleIncrease, 1.25)
        XCTAssertEqual(suggestion("Squat", archive)?.trainingMax, 185)
    }
    func testOptionalDeloadKeepsTMBeforeIncreasingAtNextCycle() {
        var archive = history("DL 5/3/1 200")
        var target = Defaults.exercise("Deadlift")
        target.wendler = WendlerSettings(includeDeload: true)
        let deload = Wendler.suggest(for: target, in: archive, date: nil)!
        XCTAssertEqual(deload.phase, .deload)
        XCTAssertEqual(deload.trainingMax, 200)
        XCTAssertEqual(deload.sets.map(\.weight), [80, 100, 120])
        XCTAssertFalse(deload.sets.last!.note.contains("+"))
        var logged = Wendler.applying(deload, to: target)
        for i in logged.sets.indices { logged.sets[i].completed = true }
        archive.sessions.append(Session(exercises: [logged], finished: true))
        let next = Wendler.suggest(for: target, in: archive, date: nil)!
        XCTAssertEqual(next.phase, .fives)
        XCTAssertEqual(next.trainingMax, 205)
    }
    func testFixedPhaseTMIncreaseAndRoundingOverrides() {
        let archive = history("BP 5/3/1 100")
        var target = Defaults.exercise("Bench press")
        target.wendler = WendlerSettings(fixedTrainingMax: 101, fixedPhase: .threes, cycleIncrease: 1.25, rounding: 1.25)
        let next = Wendler.suggest(for: target, in: archive, date: nil)!
        XCTAssertEqual(next.phase, .threes)
        XCTAssertEqual(next.trainingMax, 101)
        XCTAssertEqual(next.cycleIncrease, 1.25)
        XCTAssertEqual(next.sets.map(\.weight), [71.25, 81.25, 91.25])
        target.wendler = WendlerSettings(cycleIncrease: 0)
        XCTAssertEqual(Wendler.suggest(for: target, in: archive, date: nil)?.trainingMax, 100)
    }
    func testDisableAndImportOptOutDoNotGeneratePrescriptions() {
        let archive = history("BP 5/3/1 100")
        var target = Defaults.exercise("Bench press")
        target.wendler = WendlerSettings(enabled: false)
        XCTAssertNil(Wendler.suggest(for: target, in: archive, date: nil))
        target.wendler = WendlerSettings(useImportedHistory: false)
        XCTAssertNil(Wendler.suggest(for: target, in: archive, date: nil))
        XCTAssertNil(suggestion("Bench press", Archive()))
        target.wendler = nil; target.trainingMax = 100
        XCTAssertNil(Wendler.suggest(for: target, in: Archive(), date: nil))
    }
    func testNoHistoryExplicitSetupStartsFivesAndMissingTMCannotGuessWeights() {
        var target = Defaults.exercise("Squat")
        target.wendler = WendlerSettings(fixedTrainingMax: 150)
        XCTAssertEqual(Wendler.suggest(for: target, in: Archive(), date: nil)?.phase, .fives)
        target.wendler = WendlerSettings()
        XCTAssertNil(Wendler.suggest(for: target, in: Archive(), date: nil))
    }
    func testDraftsPartialSessionsAndFutureSessionsDoNotAdvanceCycle() {
        var archive = history("BP 5/5/5 100")
        let plan = suggestion("BP", archive)!
        var logged = Wendler.applying(plan, to: Defaults.exercise("Bench press"))
        logged.sets[0].completed = true
        let partial = Session(date: date("05.10.26"), exercises: [logged], finished: true)
        archive.sessions.append(partial)
        XCTAssertEqual(suggestion("BP", archive)?.phase, .threes)
        for i in logged.sets.indices { logged.sets[i].completed = true }
        let draft = Session(date: date("05.10.26"), exercises: [logged], finished: false)
        let future = Session(date: date("07.10.26"), exercises: [logged], finished: true)
        archive.sessions += [draft, future]
        XCTAssertEqual(suggestion("BP", archive)?.phase, .threes)
        var completed = draft; completed.finished = true
        archive.sessions.append(completed)
        XCTAssertEqual(suggestion("BP", archive)?.phase, .singles)
        XCTAssertEqual(Wendler.suggest(for: Defaults.exercise("BP"), in: archive, date: date("06.10.26"), excluding: completed.id)?.phase, .threes)
    }
    func testTemplateStartAndManualAdditionUseFreshUnloggedPrescriptions() {
        let archive = history("BP 5/5/5 100\nOHP 3/3/3 50")
        let session = Training.makeSession(in: archive, split: .push)
        let bench = session.exercises.first { $0.name == "Bench press" }!
        XCTAssertEqual(bench.sets.map(\.weight), [70, 80, 90])
        XCTAssertEqual(bench.scheme, "3/3/3")
        XCTAssertEqual(bench.prescription?.trainingMax, 100)
        XCTAssertTrue(bench.sets.allSatisfy { !$0.completed })
        let another = Training.makeSession(in: archive, split: .push)
        XCTAssertNotEqual(bench.sets[0].id, another.exercises[0].sets[0].id)
        let ohp = Training.addedExercise("Overhead press", in: archive, date: nil, excluding: nil)
        XCTAssertEqual(ohp.prescription?.phase, .singles)
        XCTAssertEqual(ohp.sets.map(\.weight), [37.5, 42.5, 47.5])
        XCTAssertNil(session.exercises.first { $0.name == "Lateral raises" }!.prescription)
    }
    func testReopeningAndSelectingTypePreservesSnapshotAndCompletedSets() {
        let archive = history("BP 5/5/5 100")
        var session = Training.makeSession(in: archive, split: .push)
        session.exercises[0].sets[0].completed = true
        session.exercises[0].sets[0].note = "Logged work"
        let original = session.exercises[0]
        let changed = Training.selectType(session, split: .upper, in: archive)
        XCTAssertEqual(changed.exercises[0], original)
        XCTAssertEqual(changed.exercises.filter { $0.name == "Bench press" }.count, 1)
    }
    func testPrescriptionAndSettingsRoundTripAndRejectInvalidValues() throws {
        var archive = history("BP 5/3/1 100")
        archive.program[0].exercises[0].wendler = WendlerSettings(cycleIncrease: 1.25, rounding: 1.25)
        archive.sessions.append(Training.makeSession(in: archive, split: .push))
        XCTAssertEqual(try ArchiveStorage.decode(ArchiveStorage.encode(archive)), archive)
        archive.program[0].exercises[0].wendler!.rounding = 0
        XCTAssertThrowsError(try archive.validated())
        archive.program[0].exercises[0].wendler = WendlerSettings(cycleIncrease: -1)
        XCTAssertThrowsError(try archive.validated())
        archive.program[0].exercises[0].wendler = nil
        archive.sessions[1].exercises[0].prescription!.trainingMax = 0
        XCTAssertThrowsError(try archive.validated())
    }
    func testHistoryImportIsAdditiveAndIdempotentWithoutAdvancingDuplicates() throws {
        let old = "BP 5/5/5 100\n——\nSquat 3/3/3 150"
        var archive = history(old)
        archive.originalHistory = old
        let logged = Session(exercises: [Defaults.exercise("Cable row")])
        archive.sessions.append(logged)
        let updated = old + "\n——\nBP 3/3/3 100"
        let result = try HistoryMerge.preview(updated, in: archive)
        XCTAssertEqual(result.added, 1)
        XCTAssertEqual(result.archive.sessions[2], logged)
        XCTAssertEqual(result.archive.sessions.last!.sourceOrder, 3)
        XCTAssertEqual(suggestion("BP", result.archive)?.phase, .singles)
        let repeated = try HistoryMerge.preview(updated, in: result.archive)
        XCTAssertEqual(repeated.added, 0)
        XCTAssertEqual(repeated.archive, result.archive)
    }
    func testHistoryImportPreservesRepeatedIdenticalOccurrencesAndRejectsEmpty() throws {
        let text = "BP 5/5/5 100\n——\nBP 5/5/5 100"
        let result = try HistoryMerge.preview(text, in: Archive())
        XCTAssertEqual(result.added, 2)
        XCTAssertEqual(try HistoryMerge.preview(text, in: result.archive).added, 0)
        XCTAssertThrowsError(try HistoryMerge.preview("# No entries", in: Archive()))
    }
}
