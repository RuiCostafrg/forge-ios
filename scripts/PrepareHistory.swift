import Foundation

// Run locally; generated personal backups must stay outside the public repository.
@main
struct PrepareHistory {
    static func main() throws {
        guard CommandLine.arguments.count == 3 else {
            print("Usage: forge-history input.md output.json")
            return
        }
        let input = URL(fileURLWithPath: CommandLine.arguments[1])
        let output = URL(fileURLWithPath: CommandLine.arguments[2])
        let text = try String(contentsOf: input, encoding: .utf8)
        let result = try HistoryMerge.preview(text, in: Archive())
        try ArchiveStorage.encode(result.archive).write(to: output, options: .atomic)
        print("Prepared \(result.added) history entries; original notes and unresolved dates are preserved.")
        for name in Wendler.mainLifts {
            let exercise = Training.addedExercise(name, in: result.archive, date: Date(), excluding: nil)
            if let plan = exercise.prescription {
                let sets = exercise.sets.map { "\($0.reps) × \($0.weight) kg" }.joined(separator: ", ")
                print("\(name): \(plan.phase.rawValue), TM \(plan.trainingMax) kg, cycle +\(plan.cycleIncrease) kg — \(sets)")
            }
        }
        _ = try ArchiveStorage.decode(Data(contentsOf: output))
    }
}
