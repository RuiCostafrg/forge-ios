import Foundation

struct ArchiveStorage {
    let directory: URL
    var file: URL { directory.appendingPathComponent("forge.json") }
    var recoveryFile: URL { directory.appendingPathComponent("forge.previous.json") }
    static func encode(_ archive: Archive) throws -> Data {
        _ = try archive.validated()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        // Foundation's native Codable dates preserve full precision across round trips.
        encoder.dateEncodingStrategy = .deferredToDate
        return try encoder.encode(archive)
    }
    static func decode(_ data: Data) throws -> Archive {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        return try decoder.decode(Archive.self, from: data).validated()
    }
    func load() throws -> Archive? {
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        return try Self.decode(Data(contentsOf: file))
    }
    func save(_ archive: Archive) throws {
        let data = try Self.encode(archive)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Keep the prior valid revision for recovery; never overwrite it with corrupt data.
        if let existing = try? Data(contentsOf: file), (try? Self.decode(existing)) != nil {
            try existing.write(to: recoveryFile, options: .atomic)
        }
        try data.write(to: file, options: .atomic)
        #if os(iOS)
        for url in [file, recoveryFile] where FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: url.path)
        }
        #endif
    }
}
