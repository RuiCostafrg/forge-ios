import Foundation

enum HistoryImporter {
    static func matches(_ pattern: String, _ text: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { match in
            (0..<match.numberOfRanges).map { index in
                let range = match.range(at: index)
                return range.location == NSNotFound ? "" : ns.substring(with: range)
            }
        }
    }

    static func canonicalName(_ raw: String) -> String {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let aliases = ["bp": "Bench press", "bench": "Bench press", "bench press": "Bench press",
                       "dl": "Deadlift", "deadlift": "Deadlift", "squat": "Squat",
                       "ohp": "Overhead press", "ibp": "Incline bench press", "incline bp": "Incline bench press",
                       "idp": "Incline dumbbell press", "incline dp": "Incline dumbbell press",
                       "sdp": "Seated dumbbell press", "sdohp": "Seated dumbbell press", "sohp": "Seated overhead press",
                       "dohp": "Dumbbell overhead press", "mohp": "Machine shoulder press"]
        return aliases[name.lowercased()] ?? name.prefix(1).uppercased() + name.dropFirst()
    }

    static func exactDate(_ label: String) -> Date? {
        let groups = matches(#"^(\d{1,2})[./](\d{1,2})[./](\d{2}|\d{4})$"#, label)
        guard let g = groups.first, let day = Int(g[1]), let month = Int(g[2]), let shortYear = Int(g[3]) else { return nil }
        let year = shortYear < 100 ? 2000 + shortYear : shortYear
        let components = DateComponents(year: year, month: month, day: day, hour: 12)
        guard let date = GymCalendar.calendar.date(from: components),
              GymCalendar.calendar.component(.day, from: date) == day,
              GymCalendar.calendar.component(.month, from: date) == month else { return nil }
        return date
    }

    // Only explicit NxRxW or RxW tokens become recorded sets. Schemes are metadata.
    static func parseSets(_ line: String) -> [LiftSet] {
        let normal = line.replacingOccurrences(of: ",", with: ".").replacingOccurrences(of: "×", with: "x")
        let pattern = #"(?<![\w./-])(?:(\d+)\s*x\s*)?(\d+)\s*x\s*(\d+(?:\.\d+)?|BW)(?![\w./])(?!\s+\d+(?:\.\d+)?(?:\s|$))"#
        return matches(pattern, normal).flatMap { group -> [LiftSet] in
            let count = Int(group[1]) ?? 1
            guard count > 0, count <= 20, let reps = Int(group[2]), reps > 0, reps <= 1000 else { return [] }
            let weight = group[3].lowercased() == "bw" ? 0 : Double(group[3]) ?? 0
            guard weight <= 2000 else { return [] }
            let note = group[3].lowercased() == "bw" ? "Bodyweight; external load only" : ""
            return (0..<count).map { _ in LiftSet(weight: weight, reps: reps, completed: true, note: note) }
        }
    }

    static func parse(_ text: String) -> [Session] {
        var sessions: [Session] = []
        var current = Session(date: nil, finished: true, needsReview: true)
        var raw: [String] = []
        var exerciseIndex: Int? = nil
        func flush() {
            if !current.exercises.isEmpty {
                current.sourceOrder = sessions.count + 1
                current.rawSource = raw.joined(separator: "\n")
                sessions.append(current)
            }
            current = Session(date: nil, finished: true, needsReview: true)
            raw = []; exerciseIndex = nil
        }
        for sourceLine in text.components(separatedBy: .newlines) {
            let line = sourceLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { raw.append(sourceLine); continue }
            if line.hasPrefix("#") { continue }
            let datePattern = #"^\d{1,2}[/.]\d{1,2}(?:[/.]\d{2}(?:\d{2})?)?$"#
            if !matches(datePattern, line).isEmpty {
                flush(); current.sourceDate = line; current.date = exactDate(line); raw.append(sourceLine); continue
            }
            if line.allSatisfy({ "—–-_ ".contains($0) }) { flush(); continue }
            if let split = Split.allCases.first(where: { $0.rawValue.caseInsensitiveCompare(line) == .orderedSame }) {
                if !current.exercises.isEmpty { flush() }
                current.split = split; raw.append(sourceLine); continue
            }
            let normal = line.replacingOccurrences(of: ",", with: ".")
            let schemeGroups = matches(#"(\d+)/(\d+)/(\d+)/?"#, normal)
            let tokenGroups = matches(#"(?<![\w./])(?:(\d+)\s*x\s*)?(\d+)\s*x\s*(\d+(?:\.\d+)?|BW)(?![\w./])"#, normal)
            let firstToken = schemeGroups.first?.first ?? tokenGroups.first?.first
            var prefix = line
            if let token = firstToken, let range = normal.range(of: token, options: .caseInsensitive) {
                prefix = String(normal[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            }
            if !schemeGroups.isEmpty, let g = matches(#"^(.+?)\s+(\d+(?:\.\d+)?)\s+\d+/\d+/\d+"#, normal).first { prefix = g[1] }
            let hasName = !prefix.isEmpty && prefix.first?.isLetter == true
            // A repeated primary lift without a delimiter is a new, undated block.
            if hasName {
                let name = canonicalName(prefix)
                let mainLifts = ["Bench press", "Squat", "Deadlift", "Overhead press"]
                if mainLifts.contains(name), current.exercises.contains(where: { $0.name == name }) { flush() }
                // Plain prose and unusual notation remain notes/source instead of invented exercises.
                let prose = ["too much", "with ", "no ", "felt ", "feels ", "myo ", "a79 ", "jose "]
                if !prose.contains(where: { line.lowercased().hasPrefix($0) }) {
                    current.exercises.append(Exercise(name: name))
                    exerciseIndex = current.exercises.count - 1
                } else {
                    current.note += (current.note.isEmpty ? "" : "\n") + line
                    raw.append(sourceLine); continue
                }
            }
            raw.append(sourceLine)
            guard let index = exerciseIndex else { continue }
            if let scheme = schemeGroups.first {
                current.exercises[index].scheme = scheme[1] + "/" + scheme[2] + "/" + scheme[3]
                let trailing = normal.components(separatedBy: scheme[0]).last ?? ""
                let maxAfter = matches(#"^\s*(\d+(?:\.\d+)?)(?:\s|$)"#, trailing).first.flatMap { Double($0[1]) }
                let maxBefore = matches(#"^.+?\s+(\d+(?:\.\d+)?)\s+\d+/\d+/\d+"#, normal).first.flatMap { Double($0[1]) }
                current.exercises[index].trainingMax = maxAfter ?? maxBefore
            }
            current.exercises[index].sets.append(contentsOf: parseSets(normal))
            if !hasName || firstToken != nil {
                current.exercises[index].note += (current.exercises[index].note.isEmpty ? "" : "\n") + line
            }
        }
        flush()
        for i in sessions.indices where sessions[i].split == .custom {
            let names = sessions[i].exercises.map(\.name)
            if names.contains("Squat") { sessions[i].split = .legs }
            else if names.contains("Deadlift") { sessions[i].split = .lower }
            else if names.contains("Bench press") { sessions[i].split = .push }
            else if names.contains(where: { $0.lowercased().contains("pull") || $0.lowercased().contains("row") }) { sessions[i].split = .pull }
        }
        return sessions
    }
}
