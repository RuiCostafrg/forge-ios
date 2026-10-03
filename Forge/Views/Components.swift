import SwiftUI

enum Theme {
    static let background = Color(red: 0.045, green: 0.065, blue: 0.08)
    static let card = Color(red: 0.085, green: 0.11, blue: 0.13)
    static let mint = Color(red: 0.68, green: 0.94, blue: 0.55)
    static let muted = Color(red: 0.57, green: 0.65, blue: 0.68)
}

extension View {
    func gymCard() -> some View {
        padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 22))
    }
    func gymScreen() -> some View {
        background(Theme.background.ignoresSafeArea())
            .toolbarBackground(Theme.background, for: .navigationBar)
    }
}

struct SectionHeading: View {
    let title: String
    var detail: String = ""
    var body: some View {
        HStack {
            Text(title).font(.title3.bold())
            Spacer()
            if !detail.isEmpty { Text(detail).font(.caption).foregroundStyle(Theme.muted) }
        }
    }
}

struct SplitBadge: View {
    let split: Split
    var body: some View {
        Label(split.rawValue, systemImage: split.symbol).font(.caption.bold())
            .foregroundStyle(Theme.mint).padding(.horizontal, 10).padding(.vertical, 6)
            .background(Theme.mint.opacity(0.1), in: Capsule())
    }
}

struct EmptyCard: View {
    let symbol: String
    let title: String
    let detail: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol).font(.title2).foregroundStyle(Theme.mint)
            Text(title).font(.headline)
            Text(detail).font(.subheadline).foregroundStyle(Theme.muted)
        }.gymCard()
    }
}

struct PrimaryButton: View {
    let title: String
    var symbol: String = "plus"
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol).font(.headline).frame(maxWidth: .infinity).padding(16)
        }.buttonStyle(.plain).foregroundStyle(Theme.background)
            .background(Theme.mint, in: RoundedRectangle(cornerRadius: 16))
    }
}

func kg(_ value: Double) -> String {
    value.formatted(.number.grouping(.never).precision(.fractionLength(0...2)).locale(Locale(identifier: "en_GB")))
}

struct ExercisePicker: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    @State private var search = ""
    var onSelect: (String) -> Void
    var filtered: [String] { store.knownExercises.filter { search.isEmpty || $0.localizedCaseInsensitiveContains(search) } }
    var body: some View {
        NavigationStack {
            List {
                if !search.trimmingCharacters(in: .whitespaces).isEmpty && !store.knownExercises.contains(where: { $0.caseInsensitiveCompare(search) == .orderedSame }) {
                    Button { choose(search.trimmingCharacters(in: .whitespaces)) } label: {
                        Label("Create “\(search)”", systemImage: "plus.circle")
                    }
                }
                ForEach(filtered, id: \.self) { name in
                    Button(name) { choose(name) }.foregroundStyle(.primary)
                }
            }.searchable(text: $search, prompt: "Search or create an exercise")
                .navigationTitle("Add exercise")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
    private func choose(_ name: String) { onSelect(name); dismiss() }
}
