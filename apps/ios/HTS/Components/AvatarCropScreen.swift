import HTSDesign
import SwiftUI
import UIKit

/// Frames the new profile photo before it goes up (#157): the photo behind the avatar's notched square, pinch to
/// zoom, drag to move, and a preview at the size of the Profile's avatar.
struct AvatarCropScreen: View {
    let image: UIImage
    let onCancel: () -> Void
    /// The part of the photo inside the frame, in image points.
    let onUse: (CGRect) -> Void

    /// Size of the avatar on the Profile (`AvatarView`).
    private static let previewSide: CGFloat = 96

    @State private var crop = AvatarCrop()
    /// The crop when the current gesture started.
    @State private var start = AvatarCrop()

    var body: some View {
        GeometryReader { geometry in
            let side = geometry.size.width - 2 * HTSSpacing.space5
            VStack(spacing: HTSSpacing.space5) {
                Text("Ajuste a foto").htsTextStyle(.uiTitle).foregroundStyle(Color.hts.bone)
                    .padding(.top, HTSSpacing.space5)
                editor(side: side)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                photo(side: Self.previewSide, frameSide: side)
                    .frame(width: Self.previewSide, height: Self.previewSide)
                    .clipShape(NotchShape(cut: HTSNotch.lg))
                    .overlay(NotchShape(cut: HTSNotch.lg).strokeBorder(Color.hts.lineStrong, lineWidth: HTSStroke.hair))
                    .accessibilityLabel("Prévia da foto")
                VStack(spacing: HTSSpacing.space3) {
                    HTSButton("Usar foto") { onUse(crop.rect(imageSize: image.size, side: side)) }
                    HTSButton("Cancelar", kind: .ghost, action: onCancel)
                }
                .padding(.horizontal, HTSSpacing.space5)
                .padding(.bottom, HTSSpacing.space5)
            }
        }
        .background(Color.hts.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    /// The whole photo, dimmed outside the frame, with the gestures.
    private func editor(side: CGFloat) -> some View {
        // The notch grows with the frame, so the frame has the avatar's exact shape.
        let shape = NotchShape(cut: HTSNotch.lg * side / Self.previewSide)
        return ZStack {
            photo(side: side, frameSide: side)
            Rectangle().fill(Color.hts.black.opacity(HTSOpacity.scrim))
                .mask {
                    Rectangle().overlay { shape.frame(width: side, height: side).blendMode(.destinationOut) }
                        .compositingGroup()
                }
                .allowsHitTesting(false)
            shape.strokeBorder(Color.hts.lineStrong, lineWidth: HTSStroke.hair)
                .frame(width: side, height: side)
                .allowsHitTesting(false)
        }
        .clipped()
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { drag in
                    var moved = start
                    moved.offset.width += drag.translation.width
                    moved.offset.height += drag.translation.height
                    crop = moved.clamped(imageSize: image.size, side: side)
                }
                .onEnded { _ in start = crop }
                .simultaneously(
                    with: MagnifyGesture()
                        .onChanged { pinch in
                            var zoomed = crop
                            zoomed.zoom = start.zoom * pinch.magnification
                            crop = zoomed.clamped(imageSize: image.size, side: side)
                        }
                        .onEnded { _ in start = crop }
                )
        )
        .accessibilityLabel("Foto. Arraste para mover e use a pinça para dar zoom.")
    }

    /// The photo as it sits behind a frame of `frameSide` points, drawn at `side` points.
    private func photo(side: CGFloat, frameSide: CGFloat) -> some View {
        let scale = side / frameSide
        let shown = AvatarCrop.displayed(image.size, side: frameSide, zoom: crop.zoom)
        return Image(uiImage: image)
            .resizable()
            .frame(width: shown.width * scale, height: shown.height * scale)
            .offset(x: crop.offset.width * scale, y: crop.offset.height * scale)
            .frame(width: side, height: side)
    }
}
