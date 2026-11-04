import HTSDesign
import HTSDomain
import SwiftUI
import Testing

@testable import HTS

@MainActor
@Suite struct RankBadgeTests {
    /// The letter's ink, measured on the rendered badge, sits in the middle of it (#193).
    @Test(arguments: ProgressionRules.bundled.ranks, [false, true])
    func theLetterIsCentered(rank: Rank, compact: Bool) throws {
        HTSFonts.register()
        let scale: CGFloat = 3
        let renderer = ImageRenderer(content: RankBadge(rank: rank, compact: compact))
        renderer.scale = scale
        let image = try #require(renderer.cgImage)
        let ink = try #require(Self.inkBounds(image, margin: Int((compact ? 3 : 6) * scale)))
        let dx = (ink.midX - CGFloat(image.width) / 2) / scale
        let dy = (ink.midY - CGFloat(image.height) / 2) / scale
        #expect(abs(dx) <= 1, "letter \(rank.id.rawValue) is \(dx) pt off horizontally")
        #expect(abs(dy) <= 1, "letter \(rank.id.rawValue) is \(dy) pt off vertically")
    }

    /// Bounds of the bright pixels (the letter on `rank-fill`), skipping the border and the S star.
    static func inkBounds(_ image: CGImage, margin: Int) -> CGRect? {
        let width = image.width, height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        guard
            let context = CGContext(
                data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in margin..<(height - margin) {
            for x in margin..<(width - margin) {
                let i = (y * width + x) * 4
                let green = Int(bytes[i + 1])
                guard green > 110 else { continue }
                minX = min(minX, x)
                maxX = max(maxX, x)
                minY = min(minY, y)
                maxY = max(maxY, y)
            }
        }
        guard maxX >= minX else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }
}
