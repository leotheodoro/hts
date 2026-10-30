import Testing
import UIKit

@testable import HTS

@Suite struct AvatarImageTests {
    @Test func cropsToASquareOf512AndEncodesJPEG() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 2000, height: 1000)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2000, height: 1000))
        }
        let data = try #require(AvatarImage.jpeg(from: image))
        #expect(Array(data.prefix(3)) == [0xFF, 0xD8, 0xFF])
        let decoded = try #require(UIImage(data: data))
        #expect(decoded.size.width * decoded.scale == 512)
        #expect(decoded.size.height * decoded.scale == 512)
        #expect(data.count < 2 * 1024 * 1024)
    }
}
