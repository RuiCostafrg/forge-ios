import Foundation
import XCTest
#if SWIFT_PACKAGE
@testable import ForgeCore
#else
@testable import Forge
#endif

final class ForgeCoreTests: XCTestCase {
    func date(_ value: String) -> Date { HistoryImporter.exactDate(value)! }

    func testSundayWeekBoundary() {
        let start = GymCalendar.weekStart(date("02.10.2026"))
        XCTAssertEqual(GymCalendar.calendar.component(.weekday, from: start), 1)
        XCTAssertEqual(GymCalendar.label(start, pattern: "yyyy-MM-dd"), "2026-09-27")
        XCTAssertTrue(GymCalendar.sameDay(GymCalendar.weekStart(date("27.09.2026")), start))
    }
    func testDefaultProgramIsSundayFirstAndOverridable() {
        XCTAssertEqual(Defaults.program.map(\.weekday), Array(1...7))
        XCTAssertEqual(Defaults.program.map(\.split), [.push, .pull, .legs, .rest, .upper, .lower, .rest])
        var archive = Archive(); archive.program[0].split = .lower
        XCTAssertNoThrow(try archive.validated())
    }
    func testTrainingMaxIsNeverCountedAsLiftedWeight() {
        let sessions = HistoryImporter.parse("26/12\nBP 5/3/1 137.5\n5x100 3x115 1x130")
        let exercise = sessions[0].exercises[0]
        XCTAssertEqual(exercise.trainingMax, 137.5)
        XCTAssertEqual(exercise.scheme, "5/3/1")
        XCTAssertEqual(exercise.sets.map(\.weight), [100, 115, 130])
        XCTAssertEqual(exercise.volume, 975)
        XCTAssertNil(sessions[0].date)
        XCTAssertEqual(sessions[0].sourceDate, "26/12")
        XCTAssertTrue(sessions[0].needsReview)
    }
    func testTrainingMaxBeforeSchemeAndDecimalComma() {
        let sessions = HistoryImporter.parse("Squat 197,5 5/3/1\n5x150 3x167,5 1x187,5")
        XCTAssertEqual(sessions[0].exercises[0].name, "Squat")
        XCTAssertEqual(sessions[0].exercises[0].trainingMax, 197.5)
        XCTAssertEqual(sessions[0].exercises[0].sets.map(\.weight), [150, 167.5, 187.5])
    }
    func testSetMultipliersAndAmbiguousNotation() {
        XCTAssertEqual(HistoryImporter.parseSets("3x5x120").count, 3)
        XCTAssertEqual(HistoryImporter.parseSets("1x1x230").first?.reps, 1)
        XCTAssertEqual(HistoryImporter.parseSets("8x44 9x44 8x44").map(\.reps), [8, 9, 8])
        XCTAssertTrue(HistoryImporter.parseSets("5/3/1 250").isEmpty)
        XCTAssertTrue(HistoryImporter.parseSets("162.5 187.5 212.5").isEmpty)
        XCTAssertTrue(HistoryImporter.parseSets("9.5x97.5 8xmax").isEmpty)
        XCTAssertTrue(HistoryImporter.parseSets("BP 3x5 120").isEmpty)
        XCTAssertTrue(HistoryImporter.parseSets("-5x100").isEmpty)
        XCTAssertEqual(HistoryImporter.parseSets("15xBW").first?.weight, 0)
        XCTAssertFalse(HistoryImporter.parseSets("15xBW").first?.note.isEmpty ?? true)
    }
    func testExactDatesDoNotInferYears() {
        XCTAssertNil(HistoryImporter.exactDate("21.07"))
        XCTAssertNil(HistoryImporter.exactDate("31.02.24"))
        XCTAssertEqual(GymCalendar.label(date("13.07.24"), pattern: "yyyy-MM-dd"), "2024-07-13")
        let sessions = HistoryImporter.parse("13.07.24\nDL 5/5/5 250\n5x212.5\n——\nBP 3/3/3 135")
        XCTAssertEqual(sessions.count, 2)
        XCTAssertNotNil(sessions[0].date)
        XCTAssertNil(sessions[1].date)
    }
    func testRepeatedLiftStartsUndatedBlock() {
        let sessions = HistoryImporter.parse("03/06\nBP 5/3/1 130\nOHP 5/5/5 70\nBP 5/5/5 132.5")
        XCTAssertEqual(sessions.count, 2)
        XCTAssertEqual(sessions[0].exercises.count, 2)
        XCTAssertNil(sessions[1].sourceDate)
    }
    func testVolumeAndEstimatedMaxExcludeWarmupsAndIncompleteSets() {
        let exercise = Exercise(name: "Bench press", sets: [
            LiftSet(weight: 100, reps: 5, completed: true),
            LiftSet(weight: 140, reps: 1, completed: true),
            LiftSet(weight: 180, reps: 1, completed: true, warmup: true),
            LiftSet(weight: 200, reps: 1, completed: false)
        ])
        let session = Session(exercises: [exercise], finished: true)
        XCTAssertEqual(session.volume, 640)
        XCTAssertEqual(session.completedSets, 2)
        XCTAssertEqual(Analytics.points(sessions: [session], exercise: "Bench press", metric: .weight)[0].value, 140)
        XCTAssertEqual(Analytics.points(sessions: [session], exercise: "Bench press", metric: .estimatedMax)[0].value, 140)
    }
    func testUnreviewedEntriesAreOptInAndChronologyIsExplicit() {
        let history = HistoryImporter.parse("BP 5/3/1 130\n1x120\n——\nBP 5/3/1 132.5\n1x125")
        XCTAssertTrue(Analytics.points(sessions: history, exercise: "Bench press", metric: .weight).isEmpty)
        let points = Analytics.points(sessions: history, exercise: "Bench press", metric: .weight, includeUnreviewed: true)
        XCTAssertEqual(points.map(\.value), [120, 125])
        XCTAssertEqual(points.map(\.order), [1, 2])
        XCTAssertTrue(points.allSatisfy { $0.date == nil })
        XCTAssertEqual(Analytics.lastExercise("Bench press", sessions: history)?.sets.first?.weight, 125)
    }
    func testNewSessionsTakePrecedenceForPreviousWeights() {
        let history = HistoryImporter.parse("BP\n5x100")
        let latest = Session(exercises: [Exercise(name: "Bench press", sets: [LiftSet(weight: 110, reps: 5, completed: true)])], finished: true)
        XCTAssertEqual(Analytics.lastExercise("Bench press", sessions: history + [latest])?.sets.first?.weight, 110)
    }
    func testJSONRoundTripKeepsHistoryAndNotes() throws {
        var archive = Archive(sessions: HistoryImporter.parse("BP 5/3/1 130\n5x100 no belt"), historyImported: true, originalHistory: "Original notes 🏋️")
        archive.program[0].exercises[0].note = "Feet planted"
        let restored = try ArchiveStorage.decode(ArchiveStorage.encode(archive))
        XCTAssertEqual(restored, archive)
    }
    func testStorageIsAtomicAndKeepsPriorValidRevision() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let storage = ArchiveStorage(directory: dir)
        XCTAssertNil(try storage.load())
        let original = Archive()
        try storage.save(original)
        var updated = original; updated.sessions = [Session()]
        try storage.save(updated)
        XCTAssertEqual(try storage.load(), updated)
        XCTAssertEqual(try ArchiveStorage.decode(Data(contentsOf: storage.recoveryFile)), original)
        try Data("corrupt".utf8).write(to: storage.file)
        XCTAssertThrowsError(try storage.load())
        XCTAssertEqual(try ArchiveStorage.decode(Data(contentsOf: storage.recoveryFile)), original)
    }
    func testInvalidBackupCannotOverwriteStore() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let storage = ArchiveStorage(directory: dir)
        let original = Archive()
        try storage.save(original)
        var invalid = Archive(); invalid.program.removeLast()
        XCTAssertThrowsError(try storage.save(invalid))
        XCTAssertEqual(try storage.load(), original)
        invalid = Archive(schemaVersion: 2)
        XCTAssertThrowsError(try invalid.validated())
        invalid = Archive(sessions: [Session(exercises: [Exercise(name: "Squat", sets: [LiftSet(weight: -10)])])])
        XCTAssertThrowsError(try invalid.validated())
        let duplicate = Session(); invalid = Archive(sessions: [duplicate, duplicate])
        XCTAssertThrowsError(try invalid.validated())
    }
    func testOffScheduleStartUsesSavedTargetsAndRest() {
        var archive = Archive()
        archive.program[0].exercises = [Defaults.exercise("My press", reps: 6, sets: 2)]
        archive.program[0].restSeconds = 180
        let started = Training.makeSession(in: archive, date: date("03.10.26"), split: .push)
        XCTAssertEqual(started.split, .push)
        XCTAssertEqual(started.exercises.map(\.name), ["My press"])
        XCTAssertEqual(started.exercises[0].sets.count, 2)
        XCTAssertTrue(started.exercises[0].sets.allSatisfy { $0.reps == 6 && $0.weight == 0 && !$0.completed })
        XCTAssertEqual(started.restDuration, 180)
        XCTAssertNil(started.restEndsAt)
    }

    func testSessionDateChoosesMatchingTemplateWhenTypeRepeats() {
        var archive = Archive()
        archive.program[2].split = .push
        archive.program[2].exercises = [Defaults.exercise("Dip", reps: 7, sets: 2)]
        archive.program[2].restSeconds = 240
        archive.program.reverse()
        let started = Training.makeSession(in: archive, date: date("06.10.26"), split: .push)
        XCTAssertEqual(started.exercises.map(\.name), ["Dip"])
        XCTAssertEqual(started.restDuration, 240)
    }

    func testUndatedSelectionUsesFirstSavedDayInSundayOrder() {
        var archive = Archive()
        archive.program[0].exercises = [Defaults.exercise("Sunday press")]
        archive.program[2].split = .push
        archive.program[2].exercises = [Defaults.exercise("Tuesday press")]
        archive.program.reverse()
        let draft = Session(date: nil)
        let selected = Training.selectType(draft, split: .push, in: archive)
        XCTAssertEqual(selected.exercises.map(\.name), ["Sunday press"])
        XCTAssertNil(selected.date)
    }

    func testAbsentSavedTypeUsesBuiltInTargets() {
        var archive = Archive()
        archive.program = archive.program.map { day in
            var day = day; day.split = .rest; day.exercises = []; return day
        }
        let started = Training.makeSession(in: archive, split: .pull)
        let defaults = Defaults.program.first { $0.split == .pull }!.exercises
        XCTAssertEqual(started.exercises.map(\.name), defaults.map(\.name))
        XCTAssertEqual(started.exercises.map { $0.sets.map(\.reps) }, defaults.map { $0.sets.map(\.reps) })
        XCTAssertEqual(started.restDuration, 90)
    }

    func testEmptyDraftPopulationUsesPreviousWeightsAndFreshIDs() {
        let previous = Session(date: date("01.10.26"), exercises: [Exercise(name: "Bench press", sets: [LiftSet(weight: 100, reps: 5, completed: true)])], finished: true)
        let archive = Archive(sessions: [previous])
        let draft = Session(date: nil)
        let selected = Training.selectType(draft, split: .push, in: archive)
        let defaults = archive.program[0].exercises
        XCTAssertEqual(selected.exercises.map(\.name), defaults.map(\.name))
        XCTAssertEqual(selected.exercises[0].sets.count, defaults[0].sets.count)
        XCTAssertTrue(selected.exercises[0].sets.allSatisfy { $0.weight == 100 && $0.reps == 8 && !$0.completed })
        let ids = selected.exercises.flatMap(\.sets).map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertTrue(Set(ids).isDisjoint(with: Set(previous.exercises.flatMap(\.sets).map(\.id))))
        XCTAssertTrue(Set(ids).isDisjoint(with: Set(defaults.flatMap(\.sets).map(\.id))))
        XCTAssertEqual(selected.id, draft.id)
    }

    func testTypeSelectionPreservesLoggedSetsAndAvoidsDuplicates() {
        let logged = Exercise(name: " bench PRESS ", sets: [LiftSet(weight: 97.5, reps: 4, completed: true, note: "Keep this set")], note: "Keep bench notes")
        let draft = Session(date: date("04.10.26"), exercises: [logged], note: "Keep session notes", durationSeconds: 300, restSeconds: 120)
        var archive = Archive(sessions: [draft])
        archive.program[0].exercises = [Defaults.exercise("Bench press", reps: 12, sets: 8), Defaults.exercise("Dip", reps: 7, sets: 2), Defaults.exercise("Dip", reps: 10, sets: 4)]
        let once = Training.selectType(draft, split: .push, in: archive)
        let twice = Training.selectType(once, split: .push, in: archive)
        XCTAssertEqual(once, twice)
        XCTAssertEqual(twice.exercises.count, 2)
        XCTAssertEqual(twice.exercises[0], logged)
        XCTAssertEqual(twice.note, draft.note)
        XCTAssertEqual(twice.durationSeconds, 300)
        XCTAssertEqual(twice.restDuration, 120)
        XCTAssertTrue(twice.exercises[1].sets.allSatisfy { $0.reps == 7 && !$0.completed })
    }

    func testRenamingPopulatedExerciseRetainsTemplateIdentity() {
        let archive = Archive()
        var draft = Training.makeSession(in: archive, split: .push)
        draft.exercises[0].name = "My renamed bench"
        let selected = Training.selectType(draft, split: .push, in: archive)
        XCTAssertEqual(selected.exercises, draft.exercises)
    }

    func testFinishedSessionChangesOnlyType() {
        let finished = Session(exercises: [Defaults.exercise("Bench press")], note: "Keep", finished: true, restSeconds: 180)
        var expected = finished; expected.split = .legs
        XCTAssertEqual(Training.selectType(finished, split: .legs, in: Archive()), expected)
    }

    func testEmptySavedTemplateDoesNotFallBackToDefaults() {
        var archive = Archive()
        archive.program[0].exercises = []
        XCTAssertTrue(Training.makeSession(in: archive, split: .push).exercises.isEmpty)
        XCTAssertTrue(Training.selectType(Session(), split: .push, in: archive).exercises.isEmpty)
    }

    func testRestSelectionPreservesWorkAndCustomStartsEmpty() {
        var archive = Archive()
        archive.program[3].exercises = [Defaults.exercise("Squat")]
        let draft = Session(exercises: [Defaults.exercise("Bench press")])
        var expected = draft; expected.split = .rest
        XCTAssertEqual(Training.selectType(draft, split: .rest, in: archive), expected)
        XCTAssertTrue(Training.makeSession(in: archive, split: .custom).exercises.isEmpty)
        XCTAssertTrue(Training.makeSession(in: archive, date: date("03.10.26")).exercises.isEmpty)
    }

    func testTemplateWeightsExcludeUnreviewedDraftWarmupAndZeroRepSets() {
        let recorded = Session(date: date("01.10.26"), exercises: [Exercise(name: "Bench press", sets: [
            LiftSet(weight: 200, reps: 1, completed: true, warmup: true),
            LiftSet(weight: 190, reps: 0, completed: true),
            LiftSet(weight: 95, reps: 5, completed: true)
        ])], finished: true)
        let imported = Session(date: date("02.10.26"), exercises: [Exercise(name: "Bench press", sets: [LiftSet(weight: 150, reps: 5, completed: true)])], finished: true, needsReview: true)
        let unfinished = Session(date: date("03.10.26"), exercises: [Exercise(name: "Bench press", sets: [LiftSet(weight: 160, reps: 5, completed: true)])])
        let latestEmpty = Session(date: date("04.10.26"), exercises: [Exercise(name: "Bench press", sets: [])], finished: true)
        let archive = Archive(sessions: [recorded, imported, unfinished, latestEmpty])
        let started = Training.makeSession(in: archive, split: .push)
        XCTAssertTrue(started.exercises[0].sets.allSatisfy { $0.weight == 95 })
    }

    func testLegacyBackupsDecodeWithoutTemplateOrRestFields() throws {
        let archive = Archive(sessions: [Session(exercises: [Defaults.exercise("Bench press")])])
        let data = try ArchiveStorage.encode(archive)
        let text = String(data: data, encoding: .utf8)!
        XCTAssertFalse(text.contains("templateID"))
        XCTAssertFalse(text.contains("restSeconds"))
        XCTAssertFalse(text.contains("restEndsAt"))
        let restored = try ArchiveStorage.decode(data)
        XCTAssertEqual(restored, archive)
        XCTAssertEqual(restored.program[0].restDuration, 90)
        XCTAssertEqual(restored.sessions[0].restDuration, 90)
    }

    func testRestDeadlineAndTemplateIdentitySurviveBackup() throws {
        var archive = Archive()
        archive.program[0].restSeconds = 180
        var session = Training.makeSession(in: archive, split: .push)
        session.restEndsAt = date("06.10.26").addingTimeInterval(180)
        archive.sessions = [session]
        let restored = try ArchiveStorage.decode(ArchiveStorage.encode(archive))
        XCTAssertEqual(restored, archive)
        XCTAssertEqual(restored.sessions[0].restEndsAt, session.restEndsAt)
        XCTAssertEqual(restored.sessions[0].exercises[0].templateID, archive.program[0].exercises[0].id)
        archive.program[0].restSeconds = 0
        XCTAssertThrowsError(try archive.validated())
        archive.program[0].restSeconds = 180
        archive.sessions[0].restSeconds = 601
        XCTAssertThrowsError(try archive.validated())
    }

    func testBundledSampleHistory() throws {
        #if SWIFT_PACKAGE
        let url = Bundle.module.url(forResource: "TrainingHistory", withExtension: "md", subdirectory: "Fixtures")!
        #else
        let url = Bundle.main.url(forResource: "TrainingHistory", withExtension: "md")!
        #endif
        let text = try String(contentsOf: url, encoding: .utf8)
        let sessions = HistoryImporter.parse(text)
        XCTAssertEqual(sessions.count, 6)
        XCTAssertTrue(sessions.allSatisfy(\.needsReview))
        XCTAssertTrue(sessions.allSatisfy { $0.rawSource != nil && $0.sourceOrder != nil })
        XCTAssertTrue(sessions.contains { $0.exercises.contains { $0.name == "Bench press" && $0.trainingMax == 92.5 } })
        XCTAssertNoThrow(try Archive(sessions: sessions, historyImported: true, originalHistory: text).validated())
        XCTAssertNoThrow(try ArchiveStorage.encode(Archive(sessions: sessions, historyImported: true, originalHistory: text)))
        print("Imported \(sessions.count) entries, \(sessions.flatMap(\.exercises).count) exercises, \(sessions.flatMap(\.exercises).flatMap(\.sets).count) explicit sets, \(sessions.filter { $0.date != nil }.count) entries with explicit full dates.")
    }
}
