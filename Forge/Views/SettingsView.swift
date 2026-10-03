import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @State private var exporting = false
    @State private var importing = false
    @State private var backup = BackupDocument(data: Data())
    @State private var pendingRestore: Data?
    @State private var confirmRestore = false
    @State private var confirmRecovery = false
    @State private var message: String?
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "dumbbell.fill").font(.largeTitle).foregroundStyle(Theme.mint)
                        Text("FORGE").font(.title.bold()).tracking(4)
                        Text("Your training. On your terms.").foregroundStyle(Theme.muted)
                        Text("Everything runs on your iPhone. No account, analytics service, or app-managed cloud sync.").font(.footnote).foregroundStyle(Theme.muted)
                    }.padding(.vertical, 10)
                }
                Section("Preferences") {
                    LabeledContent("Language", value: "English")
                    LabeledContent("Weight unit", value: "Kilograms (kg)")
                    LabeledContent("Week starts", value: "Sunday")
                }
                Section {
                    Button {
                        do { backup = BackupDocument(data: try ArchiveStorage.encode(store.archive)); exporting = true }
                        catch { message = error.localizedDescription }
                    } label: { Label("Export backup", systemImage: "square.and.arrow.up") }.disabled(store.storageBlocked)
                    Button { importing = true } label: { Label("Restore backup", systemImage: "square.and.arrow.down") }
                    Button { confirmRecovery = true } label: { Label("Recover previous saved revision", systemImage: "clock.arrow.circlepath") }
                } header: { Text("Local data") } footer: {
                    Text("Backups include your sessions, program, and original notes. Choose On My iPhone in Files for a local copy. Restoring replaces current data; export a backup first. iOS device backups follow your phone’s backup settings.")
                }
                Section("Imported history") {
                    LabeledContent("Imported entries", value: "\(store.sessions.filter { $0.sourceOrder != nil }.count)")
                    LabeledContent("Awaiting review", value: "\(store.sessions.filter(\.needsReview).count)")
                    NavigationLink("Read original T.md") { OriginalHistoryView(text: store.archive.originalHistory) }
                    Text("Dates without a year stay unresolved. 5/3/1 scheme weights are stored as training maxima. Unclear values, bodyweight/max loads, and comments remain in the original notes for you to check.").font(.footnote).foregroundStyle(Theme.muted)
                }
                Section("About") {
                    LabeledContent("Version", value: "1.0")
                    Text("Estimated 1RM uses the Epley formula for 1–12 reps. Volume sums external weight × repetitions for completed working sets. Warm-ups and unconfirmed imports are excluded from calendar totals.")
                        .font(.footnote).foregroundStyle(Theme.muted)
                }
            }.scrollContentBackground(.hidden).gymScreen().navigationTitle("Settings")
                .fileExporter(isPresented: $exporting, document: backup, contentType: .json, defaultFilename: "Forge-backup-" + GymCalendar.label(Date(), pattern: "yyyy-MM-dd")) { result in
                    if case .failure(let error) = result { message = error.localizedDescription }
                }
                .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                    do {
                        let url = try result.get()
                        let access = url.startAccessingSecurityScopedResource()
                        defer { if access { url.stopAccessingSecurityScopedResource() } }
                        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                        guard size <= 50_000_000 else { throw DataError.invalidBackup }
                        let data = try Data(contentsOf: url)
                        _ = try ArchiveStorage.decode(data)
                        pendingRestore = data; confirmRestore = true
                    } catch { message = error.localizedDescription }
                }
                .confirmationDialog("Replace current sessions and program with this backup?", isPresented: $confirmRestore, titleVisibility: .visible) {
                    Button("Restore backup", role: .destructive) {
                        guard let data = pendingRestore else { return }
                        do { try store.restore(data); message = "Backup restored." }
                        catch { message = error.localizedDescription }
                        pendingRestore = nil
                    }
                    Button("Cancel", role: .cancel) { pendingRestore = nil }
                }
                .confirmationDialog("Restore the previous saved revision?", isPresented: $confirmRecovery, titleVisibility: .visible) {
                    Button("Recover previous revision", role: .destructive) {
                        do { try store.recoverPrevious(); message = "Previous revision recovered." }
                        catch { message = "Could not recover a previous revision: \(error.localizedDescription)" }
                    }
                } message: { Text("The most recent changes will be replaced.") }
                .alert("Forge", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                    Button("OK") { message = nil }
                } message: { Text(message ?? "") }
        }
    }
}

struct OriginalHistoryView: View {
    let text: String
    private var blocks: [String] {
        let lines = text.components(separatedBy: .newlines)
        return stride(from: 0, to: lines.count, by: 40).map { start in
            lines[start..<min(start + 40, lines.count)].joined(separator: "\n")
        }
    }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    Text(block).font(.caption.monospaced()).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                }
            }.padding(20)
        }.gymScreen().navigationTitle("Original training notes").navigationBarTitleDisplayMode(.inline)
    }
}
