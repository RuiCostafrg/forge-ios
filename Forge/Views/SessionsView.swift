import SwiftUI

struct SessionsView: View {
    @EnvironmentObject var store: AppStore
    @State private var month = Date()
    @State private var selectedDate: Date? = nil
    @State private var filter = "All"
    @State private var search = ""
    @State private var editing: Session?
    private var filtered: [Session] {
        store.sessions.filter { session in
            let matchesFilter = filter == "All" || (filter == "History" && session.sourceOrder != nil) || (filter == "Review" && session.needsReview) || (filter == "Drafts" && !session.finished)
            let matchesDate = selectedDate == nil || session.date.map { GymCalendar.sameDay($0, selectedDate!) } == true
            let haystack = session.displayTitle + " " + session.note + " " + session.exercises.map(\.name).joined(separator: " ") + " " + (session.sourceDate ?? "")
            return matchesFilter && matchesDate && (search.isEmpty || haystack.localizedCaseInsensitiveContains(search))
        }.sorted {
            if $0.sourceOrder == nil && $1.sourceOrder != nil { return true }
            if $0.sourceOrder != nil && $1.sourceOrder == nil { return false }
            if let a = $0.sourceOrder, let b = $1.sourceOrder { return a > b }
            return ($0.date ?? .distantPast) > ($1.date ?? .distantPast)
        }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    MonthCalendar(month: $month, selection: $selectedDate, sessions: store.sessions)
                    if let selectedDate {
                        HStack {
                            Text(GymCalendar.label(selectedDate)).font(.subheadline.bold())
                            Spacer()
                            Button("Show all") { self.selectedDate = nil }.font(.caption)
                        }
                    }
                    Picker("Show sessions", selection: $filter) {
                        ForEach(["All", "History", "Review", "Drafts"], id: \.self) { Text($0).tag($0) }
                    }.pickerStyle(.segmented)
                    SectionHeading(title: "Training log", detail: "\(filtered.count) sessions")
                    if filtered.isEmpty {
                        EmptyCard(symbol: "calendar.badge.plus", title: "A fresh page", detail: "No sessions match this view. Use + to log a workout on any date.")
                    }
                    ForEach(filtered) { session in
                        Button { editing = session } label: { SessionRow(session: session) }.buttonStyle(.plain)
                    }
                }.padding(20)
            }.gymScreen().navigationTitle("Sessions")
                .searchable(text: $search, prompt: "Exercise, session or note")
                .toolbar { ToolbarItem(placement: .primaryAction) {
                    Button {
                        let session = store.makeSession(date: selectedDate ?? Date())
                        store.save(session); editing = session
                    } label: { Image(systemName: "plus") }.accessibilityLabel("Add session")
                } }
                .sheet(item: $editing) { SessionEditor(session: $0) }
        }
    }
}

struct MonthCalendar: View {
    @Binding var month: Date
    @Binding var selection: Date?
    let sessions: [Session]
    private var first: Date { GymCalendar.calendar.date(from: GymCalendar.calendar.dateComponents([.year, .month], from: month))! }
    private var leading: Int { GymCalendar.calendar.component(.weekday, from: first) - 1 }
    private var count: Int { GymCalendar.calendar.range(of: .day, in: .month, for: month)!.count }
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button { move(-1) } label: { Image(systemName: "chevron.left").padding(8) }.accessibilityLabel("Previous month")
                Spacer()
                Button { month = Date(); selection = nil } label: { Text(GymCalendar.label(month, pattern: "MMMM yyyy")).font(.headline) }.foregroundStyle(.primary)
                Spacer()
                Button { move(1) } label: { Image(systemName: "chevron.right").padding(8) }.accessibilityLabel("Next month")
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 8) {
                ForEach(0..<7) { index in
                    Text(String(GymCalendar.weekdays[index].prefix(3))).font(.caption2.bold()).foregroundStyle(Theme.muted).frame(maxWidth: .infinity)
                }
                ForEach(0..<(leading + count), id: \.self) { cell in
                    if cell < leading { Color.clear.frame(height: 42) }
                    else {
                        let date = GymCalendar.calendar.date(byAdding: .day, value: cell - leading, to: first)!
                        let selected = selection.map { GymCalendar.sameDay($0, date) } == true
                        let today = GymCalendar.sameDay(date, Date())
                        let done = sessions.contains { $0.finished && !$0.needsReview && $0.date.map { GymCalendar.sameDay($0, date) } == true }
                        Button { selection = selected ? nil : date } label: {
                            VStack(spacing: 4) {
                                Text("\(cell - leading + 1)").font(.subheadline.weight(today ? .bold : .regular))
                                Circle().fill(done ? Theme.mint : .clear).frame(width: 4, height: 4)
                            }.frame(maxWidth: .infinity).frame(height: 42)
                                .foregroundStyle(selected ? Theme.background : today ? Theme.mint : .primary)
                                .background(selected ? Theme.mint : .clear, in: RoundedRectangle(cornerRadius: 12))
                        }.buttonStyle(.plain).accessibilityLabel(GymCalendar.label(date) + (done ? ", session completed" : ""))
                    }
                }
            }
        }.gymCard()
    }
    private func move(_ offset: Int) { month = GymCalendar.calendar.date(byAdding: .month, value: offset, to: first)! }
}
