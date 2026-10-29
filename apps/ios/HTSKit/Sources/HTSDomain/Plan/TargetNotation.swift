import Foundation

/// Reads and writes the coach's notation (docs/decisions/0014):
///
/// | Typed      | Sets | Targets                                   | Per side |
/// | ---------- | ---- | ----------------------------------------- | -------- |
/// | `8`        | any  | `[.fixed(8)]`                             | no       |
/// | `6-6-3-3`  | 4    | `[.fixed(6), .fixed(6), .fixed(3), .fixed(3)]` | no  |
/// | `10-20`    | not 2 | `[.range(10, 20)]` (two rising numbers)  | no       |
/// | `15 a 20`  | any  | `[.range(15, 20)]` (always a range)       | no       |
/// | `12/12`    | any  | `[.fixed(12)]`                            | yes      |
/// | `máx`      | any  | `[.max]`                                  | no       |
///
/// Unit suffixes (`s`, `seg`, `min`, `m`) are accepted and ignored: the unit belongs to the exercise.
public enum TargetNotation {
    public struct Sets: Hashable, Sendable {
        public let min: Int
        public let max: Int
    }

    public struct Parsed: Hashable, Sendable {
        public let targets: [SetTarget]
        public let perSide: Bool
    }

    /// "3", "3-4" or "3 a 4".
    public static func parseSets(_ text: String) -> Sets? {
        let parts = text.lowercased().replacingOccurrences(of: " a ", with: "-")
            .split(separator: "-").map { $0.trimmingCharacters(in: .whitespaces) }
        let numbers = parts.compactMap { Int($0) }
        guard numbers.count == parts.count, (1...2).contains(numbers.count), numbers.allSatisfy({ $0 > 0 }) else {
            return nil
        }
        let sets = Sets(min: numbers[0], max: numbers.last!)
        return sets.min <= sets.max ? sets : nil
    }

    public static func formatSets(min: Int, max: Int) -> String {
        min == max ? "\(min)" : "\(min) a \(max)"
    }

    /// Nil when the text is not a target, or when a per-set list does not match `setsMax`.
    public static func parse(_ text: String, setsMax: Int) -> Parsed? {
        var body = text.lowercased().trimmingCharacters(in: .whitespaces)
        for suffix in ["seg", "min", "s", "m"] where body.hasSuffix(suffix) {
            body = String(body.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
            break
        }
        if ["máx", "max", "máximo", "maximo"].contains(body) {
            return Parsed(targets: [.max], perSide: false)
        }
        if body.contains(" a ") {
            let bounds = body.components(separatedBy: " a ").map { number(Substring($0)) }
            guard bounds.count == 2, let min = bounds[0], let max = bounds[1], min > 0, min < max else { return nil }
            return Parsed(targets: [.range(min: min, max: max)], perSide: false)
        }
        if body.contains("/") {
            let sides = body.split(separator: "/").compactMap(number)
            guard sides.count == 2, sides[0] == sides[1], sides[0] > 0 else { return nil }
            return Parsed(targets: [.fixed(sides[0])], perSide: true)
        }
        let parts = body.split(separator: "-", omittingEmptySubsequences: false)
        let numbers = parts.compactMap(number)
        guard !numbers.isEmpty, numbers.count == parts.count, numbers.allSatisfy({ $0 > 0 }) else { return nil }
        switch numbers.count {
        case 1:
            return Parsed(targets: [.fixed(numbers[0])], perSide: false)
        case 2 where numbers[0] < numbers[1] && setsMax != 2:
            return Parsed(targets: [.range(min: numbers[0], max: numbers[1])], perSide: false)
        default:
            guard numbers.count == setsMax else { return nil }
            return Parsed(targets: numbers.map(SetTarget.fixed), perSide: false)
        }
    }

    public static func format(_ targets: [SetTarget], unit: ExerciseUnit, perSide: Bool) -> String {
        let body: String
        switch targets.count == 1 ? targets[0] : nil {
        case .fixed(let value)? where perSide: body = "\(text(value))/\(text(value))"
        case .fixed(let value)?: body = text(value)
        // "15 a 20" reads back as a range whatever the number of sets.
        case .range(let min, let max)?: body = "\(text(min)) a \(text(max))"
        case .max?: return "máx"
        case nil:
            body = targets.map {
                if case .fixed(let value) = $0 { text(value) } else { "?" }
            }.joined(separator: "-")
        }
        switch unit {
        case .reps: return body
        case .seconds: return body + " s"
        case .minutes: return body + " min"
        case .meters: return body + " m"
        }
    }

    private static func number(_ part: Substring) -> Double? {
        Double(part.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
    }

    private static func text(_ value: Double) -> String {
        value.rounded() == value
            ? String(Int(value)) : String(value).replacingOccurrences(of: ".", with: ",")
    }
}

/// Load guidance shown in the profile and as a hint on each exercise, from the rep target
/// (docs/product/handoff-produto.md): 1-3 reps 90-100% RM, 4-6 70-85%, 8-12 60-75%, above 12 moderate to light.
public enum LoadGuide: String, Sendable, CaseIterable {
    case maximal
    case heavy
    case moderate
    case light

    /// Uses the highest rep target. Nil for non-rep exercises and "máx".
    public static func hint(for targets: [SetTarget], unit: ExerciseUnit) -> LoadGuide? {
        guard unit == .reps else { return nil }
        let reps = targets.compactMap { target -> Double? in
            switch target {
            case .fixed(let value): value
            case .range(_, let max): max
            case .max: nil
            }
        }
        guard let top = reps.max() else { return nil }
        switch top {
        case ...3: return .maximal
        case ...6: return .heavy
        case ...12: return .moderate
        default: return .light
        }
    }

    /// pt-BR text, as in the coach's sheets.
    public var label: String {
        switch self {
        case .maximal: "90 a 100% RM"
        case .heavy: "70 a 85% RM"
        case .moderate: "60 a 75% RM"
        case .light: "Moderada a leve"
        }
    }

    public var repRange: String {
        switch self {
        case .maximal: "1 a 3 reps"
        case .heavy: "4 a 6 reps"
        case .moderate: "8 a 12 reps"
        case .light: "Acima de 12"
        }
    }
}
