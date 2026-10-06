import Foundation

enum WendlerPhase: String, Codable, CaseIterable, Identifiable, Sendable {
    case fives = "5/5/5", threes = "3/3/3", singles = "5/3/1", deload = "Deload"
    var id: String { rawValue }
    var percentages: [Double] {
        switch self {
        case .fives: [0.65, 0.75, 0.85]
        case .threes: [0.70, 0.80, 0.90]
        case .singles: [0.75, 0.85, 0.95]
        case .deload: [0.40, 0.50, 0.60]
        }
    }
    var reps: [Int] {
        switch self {
        case .fives, .deload: [5, 5, 5]
        case .threes: [3, 3, 3]
        case .singles: [5, 3, 1]
        }
    }
    func next(deload: Bool) -> WendlerPhase {
        switch self {
        case .fives: .threes
        case .threes: .singles
        case .singles: deload ? .deload : .fives
        case .deload: .fives
        }
    }
}

// Nil on an exercise means detect 5/3/1 automatically from its history.
struct WendlerSettings: Codable, Equatable, Sendable {
    var enabled: Bool = true
    var fixedTrainingMax: Double? = nil
    var fixedPhase: WendlerPhase? = nil
    var cycleIncrease: Double? = nil
    var rounding: Double = 2.5
    var includeDeload: Bool = false
    var useImportedHistory: Bool = true

    func validate() throws {
        guard rounding.isFinite, (0.25...10).contains(rounding) else { throw DataError.invalidBackup }
        if let value = fixedTrainingMax, !value.isFinite || value <= 0 || value > 2_000 { throw DataError.invalidBackup }
        if let value = cycleIncrease, !value.isFinite || value < 0 || value > 20 { throw DataError.invalidBackup }
    }
}

// A snapshot stays with the exercise, so reopening a draft never advances it again.
struct WendlerPrescription: Codable, Equatable, Sendable {
    var phase: WendlerPhase
    var trainingMax: Double
    var cycleIncrease: Double
    var rounding: Double
    var sourceSessionID: UUID? = nil
    var sourceLabel: String
    var usesImportedOrder: Bool = false

    func validate() throws {
        try WendlerSettings(fixedTrainingMax: trainingMax, cycleIncrease: cycleIncrease, rounding: rounding).validate()
    }
    var sets: [LiftSet] {
        zip(phase.percentages, phase.reps).enumerated().map { index, pair in
            let weight = min(2_000, max(0, (trainingMax * pair.0 / rounding).rounded() * rounding))
            let plus = index == 2 && phase != .deload
            return LiftSet(weight: weight, reps: pair.1,
                           note: "\(Int((pair.0 * 100).rounded()))% TM" + (plus ? " · \(pair.1)+ reps; target is the minimum" : ""))
        }
    }
}

enum Wendler {
    static let mainLifts = ["Bench press", "Overhead press", "Squat", "Deadlift"]
    static func liftName(_ name: String) -> String? {
        let canonical = HistoryImporter.canonicalName(name)
        return mainLifts.first { $0.caseInsensitiveCompare(canonical) == .orderedSame }
    }
    private struct Entry {
        var session: Session
        var phase: WendlerPhase
        var max: Double
    }
    private static func entries(for name: String, in archive: Archive, before date: Date?, excluding: UUID?, imports: Bool) -> [Entry] {
        guard let name = liftName(name) else { return [] }
        let sessions = archive.sessions.filter { session in
            guard session.id != excluding, session.finished else { return false }
            if session.sourceOrder != nil {
                if let recorded = session.date, let date, recorded > date { return false }
                return imports
            }
            guard !session.needsReview, let recorded = session.date else { return false }
            return date.map { recorded <= $0 } ?? true
        }.sorted { a, b in
            // Imported years are often absent: retain document order, never invent dates.
            if let x = a.sourceOrder, let y = b.sourceOrder { return x < y }
            if a.sourceOrder != nil { return true }
            if b.sourceOrder != nil { return false }
            return (a.date ?? .distantPast) < (b.date ?? .distantPast)
        }
        return sessions.flatMap { session in
            session.exercises.compactMap { exercise -> Entry? in
                guard liftName(exercise.name) == name,
                      let phase = exercise.prescription?.phase ?? exercise.scheme.flatMap(WendlerPhase.init(rawValue:)),
                      let max = exercise.prescription?.trainingMax ?? exercise.trainingMax,
                      max.isFinite, max > 0, max <= 2_000 else { return nil }
                // Imported phase-only entries are valid metadata, not invented lifted sets.
                if session.sourceOrder == nil {
                    let working = exercise.sets.filter { $0.completed && !$0.warmup && $0.reps > 0 }
                    guard working.count >= 3 else { return nil }
                }
                return Entry(session: session, phase: phase, max: max)
            }
        }
    }

    static func suggest(for exercise: Exercise, in archive: Archive, date: Date?, excluding: UUID? = nil) -> WendlerPrescription? {
        guard let name = liftName(exercise.name) else { return nil }
        let settings = exercise.wendler ?? WendlerSettings()
        guard settings.enabled, (try? settings.validate()) != nil else { return nil }
        let history = entries(for: name, in: archive, before: date, excluding: excluding, imports: settings.useImportedHistory)
        let latest = history.last
        guard latest != nil || exercise.wendler?.enabled == true || exercise.scheme.flatMap(WendlerPhase.init(rawValue:)) != nil else { return nil }
        // Take the most recent modest positive change, allowing microloading and resets.
        let inferred = zip(history, history.dropFirst()).reversed().compactMap { previous, next -> Double? in
            let change = next.max - previous.max
            return change > 0 && change <= 10 ? change : nil
        }.first
        let fallback: Double = ["Bench press", "Overhead press"].contains(name) ? 2.5 : 5
        let increase = settings.cycleIncrease ?? inferred ?? fallback
        guard var max = settings.fixedTrainingMax ?? latest?.max ?? exercise.trainingMax,
              max.isFinite, max > 0, max <= 2_000 else { return nil }
        let next = latest?.phase.next(deload: settings.includeDeload) ?? .fives
        let phase = settings.fixedPhase ?? next
        if settings.fixedTrainingMax == nil, settings.fixedPhase == nil,
           let latest, (latest.phase == .singles && !settings.includeDeload) || latest.phase == .deload {
            max += increase
        }
        guard max <= 2_000 else { return nil }
        let imported = latest?.session.sourceOrder != nil
        let label: String
        if let session = latest?.session {
            label = imported ? "Imported entry \(session.sourceOrder ?? 0) · document order; date may be unresolved"
                : "Completed session · " + (session.date.map { GymCalendar.label($0) } ?? "date unknown")
        } else { label = "Program training max · first phase" }
        return WendlerPrescription(phase: phase, trainingMax: max, cycleIncrease: increase,
                                   rounding: settings.rounding, sourceSessionID: latest?.session.id,
                                   sourceLabel: label, usesImportedOrder: imported)
    }

    static func applying(_ prescription: WendlerPrescription, to exercise: Exercise) -> Exercise {
        var copy = exercise
        copy.prescription = prescription
        copy.trainingMax = prescription.trainingMax
        copy.scheme = prescription.phase.rawValue
        copy.sets = prescription.sets
        return copy
    }
}
