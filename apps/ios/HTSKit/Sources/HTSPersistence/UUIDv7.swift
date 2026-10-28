import Foundation

/// RFC 9562 UUID version 7: 48-bit Unix time in milliseconds followed by random bits.
/// Ids are generated on the client (docs/decisions/0009) and sort by creation time.
public enum UUIDv7 {
    public static func make(at date: Date = .now) -> UUID {
        var generator = SystemRandomNumberGenerator()
        return make(at: date, using: &generator)
    }

    public static func make(at date: Date, using generator: inout some RandomNumberGenerator) -> UUID {
        let millis = UInt64(max(0, date.timeIntervalSince1970 * 1000))
        var bytes = (0..<16).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
        for i in 0..<6 {
            bytes[i] = UInt8(truncatingIfNeeded: millis >> (8 * (5 - i)))
        }
        bytes[6] = (bytes[6] & 0x0F) | 0x70  // version 7
        bytes[8] = (bytes[8] & 0x3F) | 0x80  // variant 10
        return UUID(
            uuid: (
                bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
            ))
    }
}
