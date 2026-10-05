import SwiftUI
import UIKit

struct SessionEditor: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    @State private var draft: Session
    @State private var pickingExercise = false
    @State private var deleteConfirmation = false
    @State private var finishError = false
    @State private var openedAt = Date()
    @State private var elapsedRecorded = false
    @State private var deleted = false
    init(session: Session) { _draft = State(initialValue: session) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    sessionHeader
                    if !draft.finished && draft.sourceOrder == nil { restTimer }
                    if draft.needsReview { reviewCard }
                    ForEach($draft.exercises) { $exercise in
                        ExerciseCard(exercise: $exercise, sessionID: draft.id, onSetCompletion: { completed in
                            if !draft.finished {
                                draft.restEndsAt = completed ? Date().addingTimeInterval(Double(draft.restDuration)) : nil
                            }
                        }) {
                            draft.exercises.removeAll { $0.id == exercise.id }
                        } moveUp: {
                            if let index = draft.exercises.firstIndex(where: { $0.id == exercise.id }), index > 0 {
                                draft.exercises.swapAt(index, index - 1)
                            }
                        }
                    }
                    Button { pickingExercise = true } label: {
                        Label("Add exercise", systemImage: "plus.circle.fill").font(.headline).frame(maxWidth: .infinity).padding(18)
                    }.background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeading(title: "Session notes")
                        TextField("How did it feel? Sleep, energy, technique…", text: $draft.note, axis: .vertical)
                            .lineLimit(3...8).font(.subheadline)
                    }.gymCard()
                    if let raw = draft.rawSource {
                        DisclosureGroup("Original entry from T.md") {
                            Text(raw).font(.caption.monospaced()).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
                        }.gymCard()
                    }
                    if !draft.finished {
                        PrimaryButton(title: "Finish session", symbol: "checkmark") { finish() }
                    } else {
                        Label("Session complete · Changes save automatically", systemImage: "checkmark.circle.fill").font(.footnote).foregroundStyle(Theme.mint)
                        if draft.sourceOrder == nil { Button("Reopen session") { draft.finished = false; openedAt = Date(); elapsedRecorded = false } }
                    }
                    Button("Delete session", role: .destructive) { deleteConfirmation = true }.font(.footnote).padding(.top, 10)
                }.padding(20)
            }.scrollDismissesKeyboard(.interactively).gymScreen().navigationTitle(draft.finished ? "Session details" : "Log session").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Hide keyboard") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                    }
                }
                .sheet(isPresented: $pickingExercise) {
                    ExercisePicker { name in
                        var exercise = Defaults.exercise(name)
                        if let last = Analytics.lastExercise(name, sessions: store.sessions, excluding: draft.id) {
                            let weights = last.sets.filter { $0.completed && !$0.warmup }
                            for index in exercise.sets.indices where !weights.isEmpty { exercise.sets[index].weight = weights[min(index, weights.count - 1)].weight }
                        }
                        draft.exercises.append(exercise)
                    }
                }
                .onChange(of: draft) { _, value in if !deleted { store.save(value) } }
                .onDisappear { if !deleted { recordElapsed(); store.save(draft) } }
                .confirmationDialog("Delete this session permanently?", isPresented: $deleteConfirmation, titleVisibility: .visible) {
                    Button("Delete session", role: .destructive) { deleted = true; store.delete(draft.id); elapsedRecorded = true; dismiss() }
                } message: { Text("This removes the session and its sets from your phone.") }
                .alert("Log a set first", isPresented: $finishError) { Button("OK", role: .cancel) {} } message: { Text("Complete at least one working set with a positive rep count before finishing.") }
        }
    }
    private var sessionHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { SplitBadge(split: draft.split); Spacer(); Text("\(draft.completedSets) sets · \(kg(draft.volume)) kg").font(.caption).foregroundStyle(Theme.muted) }
            TextField("Session title (optional)", text: $draft.title).font(.title2.bold())
            Picker("Session type", selection: Binding(get: { draft.split }, set: {
                draft = Training.selectType(draft, split: $0, in: store.archive)
            })) { ForEach(Split.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.menu)
            Text(draft.finished ? "Reopen to add exercises from your program." : "Selecting a type adds its program exercises and keeps your existing sets.")
                .font(.caption).foregroundStyle(Theme.muted)
            if !draft.finished {
                Button("Add missing program exercises") { draft = Training.selectType(draft, split: draft.split, in: store.archive) }.font(.footnote)
            }
            if draft.needsReview {
                Toggle("Session date is known", isOn: Binding(get: { draft.date != nil }, set: { draft.date = $0 ? Date() : nil }))
            }
            if draft.date != nil {
                DatePicker("Session date", selection: Binding(get: { draft.date ?? Date() }, set: { draft.date = $0 }), displayedComponents: [.date])
            } else { Text("Original date: \(draft.sourceDate ?? "not recorded")").font(.footnote).foregroundStyle(Theme.muted) }
        }.gymCard()
    }
    private var reviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Imported entry · Review needed", systemImage: "doc.text.magnifyingglass").font(.headline).foregroundStyle(.orange)
            Text("Confirm the date, exercises, and recorded sets against the original entry below. Schemes such as 5/3/1 are training metadata; incomplete or unclear notation is preserved in notes.")
                .font(.footnote).foregroundStyle(Theme.muted)
            Button("Confirm entry for calendar & totals") { draft.needsReview = false }.disabled(draft.date == nil)
            if draft.date == nil { Text("Set the correct date to confirm this entry.").font(.caption).foregroundStyle(Theme.muted) }
        }.gymCard()
    }
    private var restTimer: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let seconds = max(0, Int((draft.restEndsAt ?? timeline.date).timeIntervalSince(timeline.date).rounded(.up)))
            HStack {
                Image(systemName: "timer").foregroundStyle(Theme.mint)
                VStack(alignment: .leading, spacing: 4) {
                    Text(draft.restEndsAt == nil ? "Rest timer · \(draft.restDuration)s" : seconds == 0 ? "Ready for your next set" : String(format: "%d:%02d remaining", seconds / 60, seconds % 60)).font(.subheadline.bold()).monospacedDigit()
                    Text("\(draft.durationSeconds / 60 + Int(timeline.date.timeIntervalSince(openedAt)) / 60) min logged").font(.caption).foregroundStyle(Theme.muted)
                }
                Spacer()
                Button(draft.restEndsAt == nil ? "Start" : "Restart") {
                    draft.restEndsAt = Date().addingTimeInterval(Double(draft.restDuration))
                }.font(.subheadline.bold())
                Menu {
                    ForEach([60, 90, 120, 180, 300], id: \.self) { value in Button("\(value) seconds") {
                        draft.restSeconds = value
                        draft.restEndsAt = Date().addingTimeInterval(Double(value))
                    } }
                    Button("Cancel timer") { draft.restEndsAt = nil }
                } label: { Image(systemName: "ellipsis").padding(8) }.accessibilityLabel("Rest timer options")
            }.gymCard()
        }
    }
    private func recordElapsed() {
        guard !elapsedRecorded, !draft.finished, draft.sourceOrder == nil else { return }
        draft.durationSeconds += max(0, Int(Date().timeIntervalSince(openedAt)))
        elapsedRecorded = true
    }
    private func finish() {
        guard draft.exercises.flatMap(\.sets).contains(where: { $0.completed && !$0.warmup && $0.reps > 0 }) else { finishError = true; return }
        recordElapsed(); draft.restEndsAt = nil; draft.finished = true; store.save(draft)
    }
}

struct ExerciseCard: View {
    @EnvironmentObject var store: AppStore
    @Binding var exercise: Exercise
    var sessionID: UUID? = nil
    var template = false
    var onSetCompletion: ((Bool) -> Void)? = nil
    var remove: () -> Void
    var moveUp: () -> Void
    @State private var rename = false
    @State private var renameText = ""
    @State private var confirmRemove = false
    var previous: Exercise? { Analytics.lastExercise(exercise.name, sessions: store.sessions, excluding: sessionID) }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Text(exercise.name).font(.headline)
                Spacer()
                Menu {
                    Button("Rename", systemImage: "pencil") { renameText = exercise.name; rename = true }
                    Button("Move up", systemImage: "arrow.up") { moveUp() }
                    Button(role: .destructive) { confirmRemove = true } label: { Label("Remove exercise", systemImage: "trash") }
                } label: { Image(systemName: "ellipsis").padding(8) }.accessibilityLabel("Exercise options")
            }
            if let previous, !template {
                let sets = previous.sets.filter { $0.completed && !$0.warmup }
                if !sets.isEmpty {
                    Text("Last logged: " + sets.prefix(5).map { "\(kg($0.weight)) × \($0.reps)" }.joined(separator: "  ·  "))
                        .font(.caption).foregroundStyle(Theme.muted)
                }
            }
            if exercise.scheme != nil || exercise.trainingMax != nil {
                HStack {
                    Text(exercise.scheme ?? "Training max").font(.caption.bold()).foregroundStyle(Theme.mint)
                    if let max = exercise.trainingMax { Text("TM \(kg(max)) kg").font(.caption).foregroundStyle(Theme.muted) }
                }
            }
            HStack {
                Text("SET").frame(width: 32)
                Text("KG").frame(maxWidth: .infinity)
                Text("REPS").frame(maxWidth: .infinity)
                Text(template ? "" : "DONE").frame(width: 40)
            }.font(.caption2.bold()).foregroundStyle(Theme.muted)
            ForEach($exercise.sets) { $set in
                let number = (exercise.sets.firstIndex { $0.id == set.id } ?? 0) + 1
                SetRow(set: $set, number: number, template: template, onCompletion: onSetCompletion) {
                    exercise.sets.removeAll { $0.id == set.id }
                }
            }
            Button {
                var set = exercise.sets.last ?? LiftSet(); set.id = UUID(); set.completed = false; set.note = ""
                exercise.sets.append(set)
            } label: { Label("Add set", systemImage: "plus").font(.subheadline.bold()).frame(maxWidth: .infinity).padding(10) }
                .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
            DisclosureGroup("Notes & training details") {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Technique, equipment, or comments", text: $exercise.note, axis: .vertical).font(.subheadline).lineLimit(2...6)
                    TextField("Scheme (optional, e.g. 5/3/1)", text: Binding(get: { exercise.scheme ?? "" }, set: { exercise.scheme = $0.isEmpty ? nil : $0 })).font(.subheadline)
                    Toggle("Track a training max", isOn: Binding(get: { exercise.trainingMax != nil }, set: { exercise.trainingMax = $0 ? 0 : nil })).font(.subheadline)
                    if exercise.trainingMax != nil {
                        HStack { Text("Training max · kg").font(.subheadline); Spacer(); WeightInput(value: Binding(get: { exercise.trainingMax ?? 0 }, set: { exercise.trainingMax = $0 })).frame(width: 100) }
                    }
                }.padding(.top, 12)
            }.font(.caption).foregroundStyle(Theme.muted)
        }.gymCard()
            .alert("Rename exercise", isPresented: $rename) {
                TextField("Exercise name", text: $renameText)
                Button("Cancel", role: .cancel) {}
                Button("Done") { exercise.name = renameText.trimmingCharacters(in: .whitespaces); if exercise.name.isEmpty { exercise.name = "Custom exercise" } }
            }
            .confirmationDialog("Remove \(exercise.name) and its sets?", isPresented: $confirmRemove, titleVisibility: .visible) {
                Button("Remove exercise", role: .destructive) { remove() }
            }
    }
}

struct SetRow: View {
    @Binding var set: LiftSet
    let number: Int
    let template: Bool
    var onCompletion: ((Bool) -> Void)? = nil
    var remove: () -> Void
    @State private var details = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button { details.toggle() } label: {
                    Text(set.warmup ? "W" : "\(number)").font(.subheadline.bold()).foregroundStyle(set.warmup ? .orange : Theme.muted).frame(width: 32, height: 44)
                }.accessibilityLabel("Set \(number) options")
                WeightInput(value: $set.weight).frame(maxWidth: .infinity)
                RepInput(value: $set.reps).frame(maxWidth: .infinity)
                if !template {
                    Button { set.completed.toggle(); onCompletion?(set.completed) } label: {
                        Image(systemName: set.completed ? "checkmark.square.fill" : "square").font(.title2)
                            .foregroundStyle(set.completed ? Theme.mint : Theme.muted).frame(width: 40, height: 44)
                    }.disabled(set.reps <= 0).accessibilityLabel(set.completed ? "Mark set incomplete" : "Complete set")
                } else { Color.clear.frame(width: 40, height: 1) }
            }
            if details {
                Toggle("Warm-up set", isOn: $set.warmup).font(.caption)
                TextField("Set note (optional)", text: $set.note, axis: .vertical).font(.caption)
                Button("Remove set", role: .destructive, action: remove).font(.caption)
            }
        }
    }
}

struct WeightInput: View {
    @Binding var value: Double
    @State private var text = ""
    @FocusState private var focused: Bool
    var body: some View {
        TextField("0", text: $text).keyboardType(.decimalPad).multilineTextAlignment(.center).focused($focused)
            .font(.body.monospacedDigit()).padding(.vertical, 12).background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 10))
            .onAppear { text = kg(value) }
            .onChange(of: value) { _, updated in if !focused { text = kg(updated) } }
            .onChange(of: text) { _, updated in
                let normalized = updated.replacingOccurrences(of: ",", with: ".")
                if normalized.isEmpty || normalized == "." { value = 0 }
                else if let parsed = Double(normalized), parsed.isFinite, (0...2000).contains(parsed) { value = parsed }
                else { text = kg(value) }
            }
            .onChange(of: focused) { _, active in if !active { text = kg(value) } }
            .accessibilityLabel("Weight in kilograms")
    }
}

struct RepInput: View {
    @Binding var value: Int
    @State private var text = ""
    @FocusState private var focused: Bool
    var body: some View {
        TextField("8", text: $text).keyboardType(.numberPad).multilineTextAlignment(.center).focused($focused)
            .font(.body.monospacedDigit()).padding(.vertical, 12).background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 10))
            .onAppear { text = "\(value)" }
            .onChange(of: value) { _, updated in if !focused { text = "\(updated)" } }
            .onChange(of: text) { _, updated in
                if updated.isEmpty { value = 0 }
                else if let parsed = Int(updated), (0...1000).contains(parsed) { value = parsed }
                else { text = "\(value)" }
            }
            .onChange(of: focused) { _, active in if !active { text = "\(value)" } }
            .accessibilityLabel("Repetitions")
    }
}
