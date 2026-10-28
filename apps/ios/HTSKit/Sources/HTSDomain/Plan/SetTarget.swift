/// Target of one set, in the exercise's unit and per side when the exercise is
/// (docs/decisions/0014). Mirrors `SetTargetSchema` in apps/api/src/db/targets.ts.
///
/// | Planilha  | Targets                               |
/// | --------- | ------------------------------------- |
/// | `3 × 8`   | `[.fixed(8)]` with 3 sets             |
/// | `6-6-3-3` | `[.fixed(6), .fixed(6), .fixed(3), .fixed(3)]` |
/// | `10-20 s` | `[.range(10, 20)]` on a seconds exercise |
/// | `máx`     | `[.max]`                              |
public enum SetTarget: Hashable, Sendable, Codable {
    case fixed(Double)
    case range(min: Double, max: Double)
    case max

    private enum CodingKeys: String, CodingKey {
        case type, value, min, max
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(String.self, forKey: .type) {
        case "fixed":
            self = .fixed(try container.decode(Double.self, forKey: .value))
        case "range":
            self = .range(
                min: try container.decode(Double.self, forKey: .min),
                max: try container.decode(Double.self, forKey: .max))
        case "max":
            self = .max
        case let other:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container, debugDescription: "Unknown set target type \(other)")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .fixed(let value):
            try container.encode("fixed", forKey: .type)
            try container.encode(value, forKey: .value)
        case .range(let min, let max):
            try container.encode("range", forKey: .type)
            try container.encode(min, forKey: .min)
            try container.encode(max, forKey: .max)
        case .max:
            try container.encode("max", forKey: .type)
        }
    }

    public var isValid: Bool {
        switch self {
        case .fixed(let value): value > 0
        case .range(let min, let max): min > 0 && min < max
        case .max: true
        }
    }
}

extension Array where Element == SetTarget {
    /// One target for every set, or one per set up to `setsMax`.
    public func fits(setsMax: Int) -> Bool {
        !isEmpty && allSatisfy(\.isValid) && (count == 1 || count == setsMax)
    }

    /// Target of the set at `index` (0-based).
    public func target(forSet index: Int) -> SetTarget? {
        count == 1 ? first : (indices.contains(index) ? self[index] : nil)
    }
}
