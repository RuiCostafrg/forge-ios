import Foundation

enum Training {
    // Resolve the session's weekday first, then the first saved day of that type.
    // An explicitly empty saved template stays empty.
    static func template(in archive: Archive, split: Split, date: Date?) -> ProgramDay? {
        guard split != .rest else { return nil }
        let weekday = date.map { GymCalendar.calendar.component(.weekday, from: $0) }
        return archive.program.first { $0.weekday == weekday && $0.split == split }
            ?? archive.program.sorted { $0.weekday < $1.weekday }.first { $0.split == split }
    }

    private static func key(_ name: String) -> String {
        HistoryImporter.canonicalName(name).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func sameExercise(_ a: Exercise, _ b: Exercise) -> Bool {
        if let id = a.templateID, id == b.templateID { return true }
        return key(a.name) == key(b.name)
    }

    private static func previousWeight(for target: Exercise, in archive: Archive, excluding: UUID?) -> Double? {
        let sessions = archive.sessions.filter {
            $0.id != excluding && $0.finished && !$0.needsReview && $0.date != nil
        }.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        for session in sessions {
            for exercise in session.exercises where sameExercise(exercise, target) {
                if let set = exercise.sets.first(where: { $0.completed && !$0.warmup && $0.reps > 0 }) {
                    return set.weight
                }
            }
        }
        return nil
    }

    static func exercises(in archive: Archive, split: Split, date: Date?, excluding: UUID? = nil) -> [Exercise] {
        guard split != .rest else { return [] }
        let targets = template(in: archive, split: split, date: date)?.exercises
            ?? Defaults.program.first { $0.split == split }?.exercises ?? []
        return targets.map { target in
            var copy = target
            copy.id = UUID()
            copy.templateID = target.templateID ?? target.id
            let weight = previousWeight(for: copy, in: archive, excluding: excluding)
            copy.sets = target.sets.map { set in
                var copy = set
                copy.id = UUID()
                copy.completed = false
                if let weight { copy.weight = weight }
                return copy
            }
            return copy
        }
    }

    static func makeSession(in archive: Archive, date: Date = Date(), split override: Split? = nil) -> Session {
        let weekday = GymCalendar.calendar.component(.weekday, from: date)
        let scheduled = archive.program.first { $0.weekday == weekday }?.split ?? .custom
        let split = override ?? (scheduled == .rest ? .custom : scheduled)
        let plan = template(in: archive, split: split, date: date)
        return Session(date: date, split: split,
                       exercises: exercises(in: archive, split: split, date: date),
                       restSeconds: plan?.restDuration ?? 90)
    }

    // Preserve logged exercises verbatim; append only missing targets to drafts.
    // Finished sessions change their label without changing their recorded work.
    static func selectType(_ session: Session, split: Split, in archive: Archive) -> Session {
        var updated = session
        updated.split = split
        guard !session.finished else { return updated }
        for target in exercises(in: archive, split: split, date: session.date, excluding: session.id) {
            if !updated.exercises.contains(where: { sameExercise($0, target) }) {
                updated.exercises.append(target)
            }
        }
        return updated
    }
}
