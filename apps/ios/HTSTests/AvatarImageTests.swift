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

    /// A 2000×1000 photo behind a 300 pt frame: at 1x it fills the frame by its height (#157).
    static let photo = CGSize(width: 2000, height: 1000)

    @Test func theCropIsWhatTheFrameShows() {
        #expect(AvatarCrop().rect(imageSize: Self.photo, side: 300) == CGRect(x: 500, y: 0, width: 1000, height: 1000))
        let zoomed = AvatarCrop(zoom: 2, offset: CGSize(width: 75, height: 0))
        // 2x shows 500 image points; 75 pt to the right is 125 image points to the left.
        #expect(zoomed.rect(imageSize: Self.photo, side: 300) == CGRect(x: 625, y: 250, width: 500, height: 500))
    }

    @Test func thePhotoNeverLeavesAGapInTheFrame() {
        let pushed = AvatarCrop(zoom: 9, offset: CGSize(width: 10_000, height: -10_000))
            .clamped(imageSize: Self.photo, side: 300)
        #expect(pushed.zoom == AvatarCrop.maxZoom)
        #expect(pushed.rect(imageSize: Self.photo, side: 300) == CGRect(x: 0, y: 750, width: 250, height: 250))
        let shrunk = AvatarCrop(zoom: 0.2, offset: CGSize(width: 0, height: 50))
            .clamped(imageSize: Self.photo, side: 300)
        #expect(shrunk == AvatarCrop(zoom: 1, offset: .zero))
    }

    @Test func theJPEGHoldsOnlyTheCrop() throws {
        let image = UIGraphicsImageRenderer(size: Self.photo).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1000, height: 1000))
            UIColor.blue.setFill()
            context.fill(CGRect(x: 1000, y: 0, width: 1000, height: 1000))
        }
        let data = try #require(AvatarImage.jpeg(from: image, crop: CGRect(x: 1200, y: 200, width: 400, height: 400)))
        let decoded = try #require(UIImage(data: data)?.cgImage)
        #expect(decoded.width == 512)
        let pixel = try #require(Self.pixel(decoded, x: 256, y: 256))
        #expect(pixel.blue > 200 && pixel.red < 60)
    }

    static func pixel(_ image: CGImage, x: Int, y: Int) -> (red: UInt8, blue: UInt8)? {
        var bytes = [UInt8](repeating: 0, count: 4)
        guard
            let context = CGContext(
                data: &bytes, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.draw(image, in: CGRect(x: -x, y: -(image.height - y - 1), width: image.width, height: image.height))
        return (bytes[0], bytes[2])
    }
}
