import Foundation

struct HistoryMergeResult {
    var archive: Archive
    var added: Int
}

enum HistoryMerge {
    private static func key(_ raw: String) -> String {
        raw.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }.joined(separator: "\n")
    }
    // Count identical occurrences: two genuinely repeated entries in a file stay two entries.
    static func preview(_ text: String, in archive: Archive) throws -> HistoryMergeResult {
        guard text.utf8.count <= 5_000_000 else { throw DataError.invalidBackup }
        let parsed = HistoryImporter.parse(text)
        guard !parsed.isEmpty else { throw DataError.invalidBackup }
        var counts: [String: Int] = [:]
        for session in archive.sessions where session.sourceOrder != nil {
            if let raw = session.rawSource { counts[key(raw), default: 0] += 1 }
        }
        var seen: [String: Int] = [:]
        var updated = archive
        var order = archive.sessions.compactMap(\.sourceOrder).max() ?? 0
        var added = 0
        for var session in parsed {
            let fingerprint = key(session.rawSource ?? "")
            seen[fingerprint, default: 0] += 1
            if seen[fingerprint, default: 0] <= counts[fingerprint, default: 0] { continue }
            order += 1; session.sourceOrder = order
            updated.sessions.append(session); added += 1
        }
        if added > 0 {
            updated.historyImported = true
            updated.originalHistory = archive.originalHistory.isEmpty ? text : archive.originalHistory + "\n\n# Additional imported history\n" + text
        }
        return HistoryMergeResult(archive: try updated.validated(), added: added)
    }
}
