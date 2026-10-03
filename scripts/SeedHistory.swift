import Foundation

@main
struct SeedHistory {
    static func main() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let resources = root.appendingPathComponent("Forge/Resources")
        let text = try String(contentsOf: resources.appendingPathComponent("TrainingHistory.md"), encoding: .utf8)
        let sessions = HistoryImporter.parse(text)
        let archive = Archive(sessions: sessions, historyImported: true, originalHistory: text)
        let data = try ArchiveStorage.encode(archive)
        try data.write(to: resources.appendingPathComponent("SeedHistory.json"), options: .atomic)
        let summary: [String: Any] = [
            "entries": sessions.count,
            "exercises": sessions.flatMap(\.exercises).count,
            "explicitSets": sessions.flatMap(\.exercises).flatMap(\.sets).count,
            "fullDates": sessions.filter { $0.date != nil }.count,
            "unreviewedEntries": sessions.filter(\.needsReview).count,
            "sourceBytes": text.utf8.count,
            "seedBytes": data.count
        ]
        let summaryData = try JSONSerialization.data(withJSONObject: summary, options: [.prettyPrinted, .sortedKeys])
        try summaryData.write(to: root.appendingPathComponent("IMPORT_REPORT.json"))
        print(String(data: summaryData, encoding: .utf8)!)
    }
}
