/// Fallback for an account without a photo (#143): the initial of the first name and of the last one, at most two
/// letters. "Leonardo Theodoro" → "LT", "Leonardo" → "L".
public enum Initials {
    public static func of(_ name: String) -> String {
        let words = name.split(whereSeparator: \.isWhitespace)
        guard let first = words.first?.first else { return "" }
        guard words.count > 1, let last = words.last?.first else { return first.uppercased() }
        return (String(first) + String(last)).uppercased()
    }
}
