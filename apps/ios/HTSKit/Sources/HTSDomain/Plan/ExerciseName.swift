/// Catalog key that makes "Barra Fixa", "barra  fixa" and "Bárra fixa" the same exercise
/// (docs/decisions/0016). Must match `normalizeExerciseName` in apps/api; both run
/// packages/fixtures/normalize-exercise-name.json.
public enum ExerciseName {
    public static func normalize(_ name: String) -> String {
        let withoutMarks = name.decomposedStringWithCanonicalMapping.unicodeScalars
            .filter { $0.properties.generalCategory != .nonspacingMark }
        return String(String.UnicodeScalarView(withoutMarks))
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}
