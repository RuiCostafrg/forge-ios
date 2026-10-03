import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var archive = Archive()
    @Published var error: String?
    @Published private(set) var storageBlocked = false
    private let storage: ArchiveStorage

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        storage = ArchiveStorage(directory: base.appendingPathComponent("Forge", isDirectory: true))
        do {
            if let loaded = try storage.load() { archive = loaded }
            else {
                if let url = Bundle.main.url(forResource: "SeedHistory", withExtension: "json") {
                    archive = try ArchiveStorage.decode(Data(contentsOf: url))
                } else if let url = Bundle.main.url(forResource: "TrainingHistory", withExtension: "md") {
                    let history = try String(contentsOf: url, encoding: .utf8)
                    archive.sessions = HistoryImporter.parse(history)
                    archive.originalHistory = history
                    archive.historyImported = true
                }
                try storage.save(archive)
            }
        } catch {
            self.error = "Could not read the local data: \(error.localizedDescription) Use Settings to restore a backup or the previous saved revision."
            storageBlocked = true
        }
    }
    var sessions: [Session] { archive.sessions }
    var program: [ProgramDay] { archive.program.sorted { $0.weekday < $1.weekday } }
    var knownExercises: [String] { Array(Set(Defaults.exerciseNames + sessions.flatMap(\.exercises).map(\.name))).sorted() }

    private func commit(_ updated: Archive) {
        guard !storageBlocked else { error = "Restore your saved data in Settings before making changes."; return }
        do { try storage.save(updated); archive = updated }
        catch { self.error = "Could not save: \(error.localizedDescription). The last saved revision has been kept." }
    }
    func save(_ session: Session) {
        var updated = archive
        if let index = updated.sessions.firstIndex(where: { $0.id == session.id }) { updated.sessions[index] = session }
        else { updated.sessions.append(session) }
        commit(updated)
    }
    func delete(_ id: UUID) {
        var updated = archive; updated.sessions.removeAll { $0.id == id }; commit(updated)
    }
    func saveProgram(_ day: ProgramDay) {
        var updated = archive
        if let index = updated.program.firstIndex(where: { $0.id == day.id }) { updated.program[index] = day }
        commit(updated)
    }
    func makeSession(date: Date = Date(), split override: Split? = nil) -> Session {
        let weekday = GymCalendar.calendar.component(.weekday, from: date)
        let day = program.first { $0.weekday == weekday }!
        let split = override ?? day.split
        let template = split == .rest ? [] : split == day.split ? day.exercises : program.first { $0.split == split }?.exercises ?? []
        let exercises = template.map { exercise in
            var copy = exercise; copy.id = UUID()
            let previous = Analytics.lastExercise(exercise.name, sessions: sessions)?.sets.filter { $0.completed && !$0.warmup }
            copy.sets = exercise.sets.enumerated().map { index, set in
                var set = set; set.id = UUID(); set.completed = false
                if let previous, !previous.isEmpty { set.weight = previous[min(index, previous.count - 1)].weight }
                return set
            }
            return copy
        }
        return Session(date: date, split: split == .rest ? .custom : split, exercises: exercises)
    }
    func restore(_ data: Data) throws {
        let updated = try ArchiveStorage.decode(data)
        try storage.save(updated)
        archive = updated; storageBlocked = false
    }
    func recoverPrevious() throws {
        let data = try Data(contentsOf: storage.recoveryFile)
        try restore(data)
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
