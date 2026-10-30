import SwiftUI
import UIKit

/// Prepares a photo for the account (#145): the centered square, 512 px wide, as JPEG. Small enough for the 2 MB
/// limit of the API and for a fast upload on mobile data.
enum AvatarImage {
    static let side: CGFloat = 512

    static func jpeg(from image: UIImage, quality: CGFloat = 0.8) -> Data? {
        let size = image.size
        let crop = min(size.width, size.height)
        guard crop > 0 else { return nil }
        let scale = side / crop
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let square = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
            let drawn = CGSize(width: size.width * scale, height: size.height * scale)
            image.draw(
                in: CGRect(
                    x: (side - drawn.width) / 2, y: (side - drawn.height) / 2, width: drawn.width,
                    height: drawn.height))
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
