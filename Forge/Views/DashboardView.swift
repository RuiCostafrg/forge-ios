import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var store: AppStore
    @State private var editing: Session?
    @State private var selectedExercise = "Bench press"
    @State private var metric: Metric = .weight
    @State private var showHistory = true
    @State private var pickingExercise = false
    @State private var chartSelection: Int?
    private var todayProgram: ProgramDay { store.program.first { $0.weekday == GymCalendar.calendar.component(.weekday, from: Date()) }! }
    private var thisWeek: [Session] {
        let start = GymCalendar.weekStart(Date())
        let end = GymCalendar.calendar.date(byAdding: .day, value: 7, to: start)!
        return store.sessions.filter { session in
            guard session.finished, !session.needsReview, let date = session.date else { return false }
            return date >= start && date < end
        }
    }
    private var points: [ProgressPoint] { Analytics.points(sessions: store.sessions, exercise: selectedExercise, metric: metric, includeUnreviewed: showHistory) }
    private var latest: [Session] {
        store.sessions.filter { $0.sourceOrder == nil }.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    todayCard
                    WeekStrip(sessions: store.sessions)
                    stats
                    progressCard
                    if store.sessions.contains(where: \.needsReview) {
                        Label("Your T.md history is here. Review dates and sets in Sessions before including it in calendar totals.", systemImage: "doc.text.magnifyingglass")
                            .font(.footnote).foregroundStyle(Theme.muted).gymCard()
                    }
                    SectionHeading(title: "Recent sessions")
                    if latest.isEmpty {
                        EmptyCard(symbol: "dumbbell", title: "Your next chapter starts here", detail: "Start a session to log your first workout in Forge. Your imported training notes are in Sessions.")
                    } else {
                        ForEach(Array(latest.prefix(3))) { session in
                            Button { editing = session } label: { SessionRow(session: session) }.buttonStyle(.plain)
                        }
                    }
                }.padding(20)
            }.gymScreen().navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .principal) { Text("FORGE").font(.caption.bold()).tracking(5).foregroundStyle(Theme.mint) } }
                .sheet(item: $editing) { SessionEditor(session: $0) }
                .sheet(isPresented: $pickingExercise) { ExercisePicker { selectedExercise = $0; chartSelection = nil } }
        }
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(GymCalendar.label(Date(), pattern: "EEEE, d MMMM").uppercased())
                .font(.caption.weight(.semibold)).tracking(1.5).foregroundStyle(Theme.muted)
            Text("Built one rep\nat a time.").font(.system(size: 36, weight: .bold, design: .rounded))
        }
    }
    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text("TODAY’S PLAN").font(.caption.bold()).tracking(1.5).foregroundStyle(Theme.muted); Spacer(); SplitBadge(split: todayProgram.split) }
            Text(todayProgram.split == .rest ? "Recover. Come back stronger." : todayProgram.split.rawValue + " day")
                .font(.title.bold())
            Text(todayProgram.split == .rest ? "Take a rest day or choose any workout." : "\(todayProgram.exercises.count) exercises · Your plan, your pace")
                .font(.subheadline).foregroundStyle(Theme.muted)
            PrimaryButton(title: todayProgram.split == .rest ? "Log a workout" : "Start session", symbol: "play.fill") { start() }
            Menu {
                ForEach(Split.allCases.filter { $0 != .rest }) { split in Button(split.rawValue) { start(split) } }
            } label: { Label("Choose a different workout", systemImage: "arrow.triangle.swap").font(.footnote).foregroundStyle(Theme.muted) }
        }.gymCard()
    }
    private func start(_ split: Split? = nil) {
        let session = store.makeSession(split: split); store.save(session); editing = session
    }
    private var stats: some View {
        HStack(spacing: 10) {
            StatTile(value: "\(thisWeek.count)", label: "This week", symbol: "calendar")
            StatTile(value: "\(thisWeek.reduce(0) { $0 + $1.completedSets })", label: "Working sets", symbol: "checkmark.circle")
            StatTile(value: kg(thisWeek.reduce(0) { $0 + $1.volume } / 1000) + "t", label: "Volume", symbol: "scalemass")
        }
    }
    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeading(title: "Strength over time")
            Button { pickingExercise = true } label: {
                HStack { Text(selectedExercise).font(.headline); Spacer(); Image(systemName: "chevron.up.chevron.down").font(.caption) }
            }.foregroundStyle(Theme.mint)
            Picker("Metric", selection: $metric) {
                ForEach(Metric.allCases) { metric in Text(metric.rawValue).tag(metric) }
            }.pickerStyle(.menu)
            Toggle("Include imported history", isOn: $showHistory).font(.footnote)
            if let last = points.last {
                let selected = points.first { $0.order == chartSelection } ?? last
                HStack(alignment: .firstTextBaseline) {
                    Text(kg(selected.value)).font(.system(size: 38, weight: .bold, design: .rounded)).contentTransition(.numericText())
                    Text("kg").foregroundStyle(Theme.muted)
                    Spacer()
                    if let first = points.first, points.count > 1, first.value > 0 {
                        let change = (last.value - first.value) / first.value * 100
                        Text((change >= 0 ? "+" : "") + kg(change) + "%")
                            .font(.subheadline.bold()).foregroundStyle(change >= 0 ? Theme.mint : .orange)
                    }
                }
                Text(selected.label).font(.caption).foregroundStyle(Theme.muted)
                Chart(points) { point in
                    LineMark(x: .value("Session", point.order), y: .value("kg", point.value))
                        .foregroundStyle(Theme.mint).interpolationMethod(.linear)
                    if points.count == 1 || point.order == chartSelection {
                        PointMark(x: .value("Session", point.order), y: .value("kg", point.value)).foregroundStyle(Theme.mint)
                    }
                }
                .chartXSelection(value: $chartSelection)
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine().foregroundStyle(.white.opacity(0.05))
                    AxisValueLabel {
                        if let order = value.as(Int.self), let point = points.first(where: { $0.order == order }) {
                            Text(showHistory ? "\(order)" : point.date.map { GymCalendar.label($0, pattern: "d MMM") } ?? "?")
                        }
                    }
                } }
                .chartYAxis { AxisMarks(position: .leading) }
                .frame(height: 180)
                Text(showHistory ? "Note order, then new sessions. Imported entries may contain duplicates or incomplete sets; review them in Sessions." : "Confirmed sessions in date order. Tap the chart to inspect a session.")
                    .font(.caption).foregroundStyle(Theme.muted)
                if metric == .estimatedMax { Text("Epley estimate from working sets of 1–12 reps. A guide, not a tested maximum.").font(.caption).foregroundStyle(Theme.muted) }
                if metric == .trainingMax { Text("5/3/1 training maxima from your notes, separate from weights actually lifted.").font(.caption).foregroundStyle(Theme.muted) }
            } else {
                Text("No recorded \(metric.rawValue.lowercased()) for this exercise yet. Log working sets or review your history.")
                    .foregroundStyle(Theme.muted).padding(.vertical, 25)
            }
        }.gymCard()
    }
}

struct StatTile: View {
    let value: String
    let label: String
    let symbol: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(Theme.mint)
            Text(value).font(.title2.bold()).minimumScaleFactor(0.6).lineLimit(1)
            Text(label).font(.caption2).foregroundStyle(Theme.muted)
        }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
    }
}

struct WeekStrip: View {
    let sessions: [Session]
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(title: "Your week", detail: "SUN — SAT")
            HStack(spacing: 0) {
                ForEach(0..<7) { offset in
                    let date = GymCalendar.calendar.date(byAdding: .day, value: offset, to: GymCalendar.weekStart(Date()))!
                    let isToday = GymCalendar.sameDay(date, Date())
                    let done = sessions.contains { $0.finished && !$0.needsReview && $0.date.map { GymCalendar.sameDay($0, date) } == true }
                    VStack(spacing: 9) {
                        Text(String(GymCalendar.weekdays[offset].prefix(1))).font(.caption).foregroundStyle(Theme.muted)
                        Text(GymCalendar.label(date, pattern: "d")).font(.subheadline.bold())
                            .frame(width: 34, height: 34)
                            .foregroundStyle(isToday ? Theme.background : .primary)
                            .background(isToday ? Theme.mint : .clear, in: Circle())
                        Image(systemName: done ? "checkmark.circle.fill" : "circle.fill").font(.system(size: done ? 11 : 4)).foregroundStyle(done ? Theme.mint : Theme.muted.opacity(0.4))
                    }.frame(maxWidth: .infinity)
                }
            }
        }
    }
}

struct SessionRow: View {
    let session: Session
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: session.split.symbol).font(.title3).foregroundStyle(Theme.mint)
                .frame(width: 44, height: 44).background(Theme.mint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 5) {
                Text(session.displayTitle).font(.headline)
                Text(session.date.map { GymCalendar.label($0) } ?? session.sourceDate.map { $0 + " · year unknown" } ?? "Date unknown")
                    .font(.caption).foregroundStyle(Theme.muted)
                Text("\(session.exercises.count) exercises · \(session.completedSets) sets" + (session.needsReview ? " · Review needed" : session.finished ? "" : " · In progress"))
                    .font(.caption2).foregroundStyle(session.needsReview ? .orange : Theme.muted)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.muted)
        }.gymCard()
    }
}
