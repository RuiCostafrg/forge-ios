import SwiftUI

struct ProgramView: View {
    @EnvironmentObject var store: AppStore
    @State private var editing: ProgramDay?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("A plan that moves\nwith you.").font(.system(size: 32, weight: .bold, design: .rounded))
                        Text("Push · Pull · Legs · Upper · Lower\nTap a day to change its workout and exercises.").font(.subheadline).foregroundStyle(Theme.muted)
                    }.padding(.bottom, 8)
                    ForEach(store.program) { day in
                        Button { editing = day } label: {
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(String(GymCalendar.weekdays[day.weekday - 1].prefix(3)).uppercased()).font(.caption.bold()).tracking(1.5).foregroundStyle(Theme.muted)
                                    Text(day.split.rawValue).font(.title3.bold())
                                }.frame(width: 82, alignment: .leading)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(day.split == .rest ? "Recovery day" : "\(day.exercises.count) exercises · \(day.restDuration)s rest").font(.subheadline.bold())
                                    Text(day.exercises.prefix(3).map(\.name).joined(separator: " · ")).font(.caption).foregroundStyle(Theme.muted).lineLimit(2)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.muted)
                            }.gymCard()
                        }.buttonStyle(.plain)
                    }
                    Text("Main lifts with 5/3/1 history get the next phase and percentage weights automatically. Other exercises use your saved targets and last confirmed working weight. Open an exercise’s 5/3/1 settings to override or disable suggestions.")
                        .font(.footnote).foregroundStyle(Theme.muted).padding(.top, 6)
                }.padding(20)
            }.gymScreen().navigationTitle("Your program")
                .sheet(item: $editing) { ProgramEditor(day: $0) }
        }
    }
}

struct ProgramEditor: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    @State private var day: ProgramDay
    @State private var picking = false
    @State private var discard = false
    init(day: ProgramDay) { _day = State(initialValue: day) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Workout", selection: $day.split) { ForEach(Split.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.menu)
                        Text("Choose the session type, then customise the exercises, sets, and rep targets below. Existing sessions keep their own exercises.")
                            .font(.footnote).foregroundStyle(Theme.muted)
                        Stepper("Rest between sets · \(day.restDuration)s", value: Binding(get: { day.restDuration }, set: { day.restSeconds = $0 }), in: 15...600, step: 15)
                            .font(.subheadline)
                    }.gymCard()
                    if day.split == .rest {
                        EmptyCard(symbol: "moon.fill", title: "Time to recover", detail: "This day suggests rest. You can still log any session from Overview or Sessions.")
                    } else {
                        ForEach($day.exercises) { $exercise in
                            ExerciseCard(exercise: $exercise, template: true) {
                                day.exercises.removeAll { $0.id == exercise.id }
                            } moveUp: {
                                if let index = day.exercises.firstIndex(where: { $0.id == exercise.id }), index > 0 { day.exercises.swapAt(index, index - 1) }
                            }
                        }
                        PrimaryButton(title: "Add exercise") { picking = true }
                    }
                }.padding(20)
            }.gymScreen().navigationTitle(GymCalendar.weekdays[day.weekday - 1]).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") { store.saveProgram(day); dismiss() }.fontWeight(.bold) }
                }
                .sheet(isPresented: $picking) { ExercisePicker { day.exercises.append(Defaults.exercise($0)) } }
        }
    }
}
