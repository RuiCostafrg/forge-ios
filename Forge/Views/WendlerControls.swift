import SwiftUI

struct WendlerControls: View {
    @Binding var exercise: Exercise
    let template: Bool
    private var settings: Binding<WendlerSettings> {
        Binding(get: { exercise.wendler ?? WendlerSettings() }, set: { exercise.wendler = $0 })
    }
    var body: some View {
        DisclosureGroup("5/3/1 settings") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Use 5/3/1 suggestions", isOn: settings.enabled)
                Text("Automatic uses this lift’s last phase and TM. Your phase labels take priority over recorded rep counts. Three working sets use standard 5/3/1 percentages; warm-ups and supplemental sets can be added separately.")
                    .font(.caption).foregroundStyle(Theme.muted)
                Picker("Phase", selection: settings.fixedPhase) {
                    Text("Automatic next phase").tag(Optional<WendlerPhase>.none)
                    ForEach(WendlerPhase.allCases) { Text($0.rawValue).tag(Optional($0)) }
                }
                Toggle("Use fixed training max", isOn: Binding(get: { settings.wrappedValue.fixedTrainingMax != nil }, set: {
                    settings.wrappedValue.fixedTrainingMax = $0 ? max(1, exercise.trainingMax ?? 100) : nil
                }))
                if settings.wrappedValue.fixedTrainingMax != nil {
                    HStack {
                        Text("Training max · kg")
                        WeightInput(value: Binding(get: { settings.wrappedValue.fixedTrainingMax ?? 100 }, set: {
                            if $0 > 0 && $0 <= 2_000 { settings.wrappedValue.fixedTrainingMax = $0 }
                        })).frame(width: 100)
                    }
                    Text("A fixed TM stays the same until you change it.").font(.caption).foregroundStyle(Theme.muted)
                }
                Toggle("Set cycle increase", isOn: Binding(get: { settings.wrappedValue.cycleIncrease != nil }, set: {
                    settings.wrappedValue.cycleIncrease = $0 ? (exercise.prescription?.cycleIncrease ?? 2.5) : nil
                }))
                if settings.wrappedValue.cycleIncrease != nil {
                    Stepper("Cycle increase · \(kg(settings.wrappedValue.cycleIncrease ?? 0)) kg", value: Binding(get: {
                        settings.wrappedValue.cycleIncrease ?? 0
                    }, set: { settings.wrappedValue.cycleIncrease = $0 }), in: 0...20, step: 0.25)
                }
                Text("Automatic increase uses the latest positive TM change up to 10 kg. With no change recorded, defaults are 2.5 kg for presses and 5 kg for squat/deadlift.")
                    .font(.caption).foregroundStyle(Theme.muted)
                Picker("Round weight to", selection: settings.rounding) {
                    ForEach([0.25, 0.5, 1, 1.25, 2.5, 5, 10], id: \.self) { Text("\(kg($0)) kg").tag($0) }
                }
                Toggle("Deload after 5/3/1", isOn: settings.includeDeload)
                Toggle("Use imported phase history", isOn: settings.useImportedHistory)
                Text("Undated imports use document order, including entries awaiting calendar review. Turn this off to use only completed sessions recorded in Forge.")
                    .font(.caption).foregroundStyle(Theme.muted)
                if template {
                    Text("These controls apply when starting sessions. Fixed phase overrides automatic progression. Existing sessions keep their sets.")
                        .font(.caption).foregroundStyle(Theme.muted)
                }
            }.font(.subheadline).padding(.top, 10)
        }.font(.caption).foregroundStyle(Theme.muted)
    }
}
