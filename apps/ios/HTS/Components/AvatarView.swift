import HTSDesign
import HTSDomain
import SwiftUI

/// The account photo in the notched square of the brand, or the initials when there is none (#143).
struct AvatarView: View {
    let url: URL?
    let name: String
    var size: CGFloat = 96

    var body: some View {
        let shape = NotchShape(cut: HTSNotch.lg)
        ZStack {
            shape.fill(Color.hts.surface)
            initials
            if let url {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color.hts.lineStrong, lineWidth: HTSStroke.hair))
        .accessibilityElement()
        .accessibilityLabel("Foto de \(name)")
    }

    private var initials: some View {
        Text(verbatim: Initials.of(name))
            .htsTextStyle(.uiDisplay)
            .foregroundStyle(Color.hts.bone)
            .minimumScaleFactor(0.5)
    }
}
