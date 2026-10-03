import Foundation

enum Split: String, Codable, CaseIterable, Identifiable, Sendable {
    case push = "Push", pull = "Pull", legs = "Legs", upper = "Upper", lower = "Lower", custom = "Custom", rest = "Rest"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .push: "arrow.up.right"
        case .pull: "arrow.down.left"
        case .legs: "figure.strengthtraining.functional"
        case .upper: "figure.strengthtraining.traditional"
        case .lower: "figure.step.training"
        case .custom: "dumbbell.fill"
        case .rest: "moon.fill"
        }
    }
}

struct LiftSet: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var weight: Double = 0
    var reps: Int = 8
    var completed: Bool = false
    var warmup: Bool = false
    var note: String = ""
    var volume: Double { completed && !warmup ? weight * Double(reps) : 0 }
    var estimatedMax: Double { reps == 1 ? weight : weight * (1 + Double(reps) / 30) }
}

struct Exercise: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var sets: [LiftSet] = []
    var note: String = ""
    var trainingMax: Double? = nil
    var scheme: String? = nil
    var volume: Double { sets.reduce(0) { $0 + $1.volume } }
}

struct Session: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var date: Date? = Date()
    var split: Split = .custom
    var title: String = ""
    var exercises: [Exercise] = []
    var note: String = ""
    var finished: Bool = false
    var durationSeconds: Int = 0
    var sourceOrder: Int? = nil
    var sourceDate: String? = nil
    var rawSource: String? = nil
    var needsReview: Bool = false
    var displayTitle: String { title.isEmpty ? split.rawValue + " session" : title }
    var volume: Double { exercises.reduce(0) { $0 + $1.volume } }
    var completedSets: Int { exercises.flatMap(\.sets).filter { $0.completed && !$0.warmup && $0.reps > 0 }.count }
}

struct ProgramDay: Identifiable, Codable, Equatable, Sendable {
    // Calendar weekday: Sunday = 1.
    var weekday: Int
    var split: Split
    var exercises: [Exercise]
    var id: Int { weekday }
}

struct Archive: Codable, Equatable, Sendable {
    var schemaVersion: Int = 1
    var sessions: [Session] = []
    var program: [ProgramDay] = Defaults.program
    var historyImported: Bool = false
    var originalHistory: String = ""

    func validated() throws -> Archive {
        guard schemaVersion == 1 else { throw DataError.unsupportedVersion }
        guard program.count == 7, Set(program.map(\.weekday)) == Set(1...7),
              Set(sessions.map(\.id)).count == sessions.count,
              sessions.count <= 50_000 else { throw DataError.invalidBackup }
        for exercises in sessions.map(\.exercises) + program.map(\.exercises) {
            guard exercises.count <= 200, Set(exercises.map(\.id)).count == exercises.count else { throw DataError.invalidBackup }
            for exercise in exercises {
                guard exercise.sets.count <= 200, !exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      Set(exercise.sets.map(\.id)).count == exercise.sets.count else { throw DataError.invalidBackup }
                if let max = exercise.trainingMax, !max.isFinite || max < 0 || max > 2_000 { throw DataError.invalidBackup }
                for set in exercise.sets {
                    guard set.weight.isFinite, set.weight >= 0, set.weight <= 2_000,
                          set.reps >= 0, set.reps <= 1_000 else { throw DataError.invalidBackup }
                }
            }
        }
        return self
    }
}

enum DataError: LocalizedError {
    case unsupportedVersion, invalidBackup
    var errorDescription: String? {
        switch self {
        case .unsupportedVersion: "This backup was made with a newer version of Forge."
        case .invalidBackup: "This file is not a valid Forge backup. Your current data has been kept."
        }
    }
}

enum Defaults {
    static func exercise(_ name: String, _ weight: Double = 0, reps: Int = 8, sets: Int = 3) -> Exercise {
        Exercise(name: name, sets: (0..<sets).map { _ in LiftSet(weight: weight, reps: reps) })
    }
    static var program: [ProgramDay] {
        [
            ProgramDay(weekday: 1, split: .push, exercises: [exercise("Bench press"), exercise("Incline dumbbell press"), exercise("Shoulder press"), exercise("Lateral raises", reps: 12), exercise("Triceps pushdown", reps: 12)]),
            ProgramDay(weekday: 2, split: .pull, exercises: [exercise("Lat pulldown"), exercise("Barbell row"), exercise("Cable row"), exercise("Biceps curl", reps: 12)]),
            ProgramDay(weekday: 3, split: .legs, exercises: [exercise("Squat", reps: 5), exercise("Leg press"), exercise("Leg curl", reps: 12), exercise("Leg extension", reps: 12), exercise("Calf raises", reps: 15)]),
            ProgramDay(weekday: 4, split: .rest, exercises: []),
            ProgramDay(weekday: 5, split: .upper, exercises: [exercise("Bench press"), exercise("Lat pulldown"), exercise("Incline dumbbell press"), exercise("Cable row"), exercise("Lateral raises", reps: 12)]),
            ProgramDay(weekday: 6, split: .lower, exercises: [exercise("Deadlift", reps: 5), exercise("Bulgarian split squat"), exercise("Leg curl", reps: 12), exercise("Leg extension", reps: 12), exercise("Calf raises", reps: 15)]),
            ProgramDay(weekday: 7, split: .rest, exercises: [])
        ]
    }
    static let exerciseNames = ["Bench press", "Squat", "Deadlift", "Overhead press", "Incline bench press", "Incline dumbbell press", "Shoulder press", "Lateral raises", "Chest fly", "Triceps pushdown", "Overhead triceps extension", "Lat pulldown", "Barbell row", "Cable row", "Machine row", "Biceps curl", "Hammer curl", "Leg press", "Bulgarian split squat", "Leg curl", "Leg extension", "Calf raises", "Leg raises"]
}

enum GymCalendar {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_GB")
        calendar.firstWeekday = 1
        calendar.minimumDaysInFirstWeek = 1
        return calendar
    }
    static let weekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    static func weekStart(_ date: Date) -> Date {
        let cal = calendar
        let day = cal.startOfDay(for: date)
        return cal.date(byAdding: .day, value: -(cal.component(.weekday, from: day) - 1), to: day)!
    }
    static func sameDay(_ a: Date, _ b: Date) -> Bool { calendar.isDate(a, inSameDayAs: b) }
    static func label(_ date: Date, pattern: String = "EEE, d MMM yyyy") -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}

enum Metric: String, CaseIterable, Identifiable {
    case weight = "Top weight", estimatedMax = "Est. 1RM", volume = "Volume", trainingMax = "Training max"
    var id: String { rawValue }
}

struct ProgressPoint: Identifiable {
    var id: UUID
    var date: Date?
    var order: Int
    var value: Double
    var label: String
}

enum Analytics {
    static func points(sessions: [Session], exercise name: String, metric: Metric, includeUnreviewed: Bool = false) -> [ProgressPoint] {
        let ordered = sessions.filter { $0.finished && (includeUnreviewed || !$0.needsReview) }.sorted {
            if includeUnreviewed {
                if let a = $0.sourceOrder, let b = $1.sourceOrder { return a < b }
                if $0.sourceOrder != nil && $1.sourceOrder == nil { return true }
                if $0.sourceOrder == nil && $1.sourceOrder != nil { return false }
            }
            return ($0.date ?? .distantPast) < ($1.date ?? .distantPast)
        }
        return ordered.compactMap { session -> ProgressPoint? in
            let matches = session.exercises.filter { $0.name.caseInsensitiveCompare(name) == .orderedSame }
            let sets = matches.flatMap(\.sets).filter { $0.completed && !$0.warmup && $0.reps > 0 }
            let value: Double?
            switch metric {
            case .weight: value = sets.map(\.weight).max()
            case .estimatedMax: value = sets.filter { $0.reps <= 12 }.map(\.estimatedMax).max()
            case .volume: value = sets.isEmpty ? nil : sets.reduce(0) { $0 + $1.volume }
            case .trainingMax: value = matches.compactMap(\.trainingMax).max()
            }
            guard let value else { return nil }
            return ProgressPoint(id: session.id, date: session.date, order: 0, value: value,
                                 label: session.date.map { GymCalendar.label($0) } ?? session.sourceDate ?? "Date unknown")
        }.enumerated().map { index, point in
            var point = point; point.order = index + 1; return point
        }
    }
    static func lastExercise(_ name: String, sessions: [Session], excluding: UUID? = nil) -> Exercise? {
        let ordered = sessions.filter { $0.id != excluding && $0.finished }.sorted {
            if $0.sourceOrder != nil && $1.sourceOrder == nil { return false }
            if $0.sourceOrder == nil && $1.sourceOrder != nil { return true }
            if let a = $0.sourceOrder, let b = $1.sourceOrder { return a > b }
            return ($0.date ?? .distantPast) > ($1.date ?? .distantPast)
        }
        return ordered.lazy.compactMap { session in session.exercises.first { $0.name.caseInsensitiveCompare(name) == .orderedSame } }.first
    }
}
