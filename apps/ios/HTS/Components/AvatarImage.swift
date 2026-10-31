import SwiftUI
import UIKit

/// Where the photo sits behind the square frame of the crop screen (#157). At zoom 1 the photo covers the frame by
/// its short side; `offset` moves it from the center, in frame points.
struct AvatarCrop: Equatable {
    static let maxZoom: CGFloat = 4

    var zoom: CGFloat = 1
    var offset: CGSize = .zero

    /// The photo's size on screen behind a frame of `side` points.
    static func displayed(_ imageSize: CGSize, side: CGFloat, zoom: CGFloat) -> CGSize {
        let short = min(imageSize.width, imageSize.height)
        guard short > 0 else { return .zero }
        return CGSize(
            width: imageSize.width * side * zoom / short, height: imageSize.height * side * zoom / short)
    }

    /// Zoom between 1 and `maxZoom`, and an offset that keeps the frame covered.
    func clamped(imageSize: CGSize, side: CGFloat) -> AvatarCrop {
        let zoom = min(max(zoom, 1), Self.maxZoom)
        let shown = Self.displayed(imageSize, side: side, zoom: zoom)
        let maxX = max(0, (shown.width - side) / 2)
        let maxY = max(0, (shown.height - side) / 2)
        return AvatarCrop(
            zoom: zoom,
            offset: CGSize(width: min(max(offset.width, -maxX), maxX), height: min(max(offset.height, -maxY), maxY)))
    }

    /// The part of the photo inside the frame, in image points.
    func rect(imageSize: CGSize, side: CGFloat) -> CGRect {
        let short = min(imageSize.width, imageSize.height)
        let width = short / zoom
        let shiftX = offset.width * short / (side * zoom)
        let shiftY = offset.height * short / (side * zoom)
        return CGRect(
            x: imageSize.width / 2 - width / 2 - shiftX, y: imageSize.height / 2 - width / 2 - shiftY, width: width,
            height: width)
    }
}

/// Prepares a photo for the account (#145): the square `crop` (the centered square by default), 512 px wide, as
/// JPEG. Small enough for the 2 MB limit of the API and for a fast upload on mobile data.
enum AvatarImage {
    static let side: CGFloat = 512

    static func jpeg(from image: UIImage, crop: CGRect? = nil, quality: CGFloat = 0.8) -> Data? {
        let size = image.size
        let crop = crop ?? AvatarCrop().rect(imageSize: size, side: side)
        guard crop.width > 0, size.width > 0, size.height > 0 else { return nil }
        let scale = side / crop.width
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let square = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
            image.draw(
                in: CGRect(
                    x: -crop.minX * scale, y: -crop.minY * scale, width: size.width * scale,
                    height: size.height * scale))
        }
        return square.jpegData(compressionQuality: quality)
    }
}

/// The system camera, for "Tirar foto". Answers the photo taken, or nil when cancelled.
struct CameraPicker: UIViewControllerRepresentable {
    let onFinish: (UIImage?) -> Void

    static var isAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraDevice = .front
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onFinish: (UIImage?) -> Void

        init(onFinish: @escaping (UIImage?) -> Void) { self.onFinish = onFinish }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            onFinish(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onFinish(nil) }
    }
}
