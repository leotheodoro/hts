import HTSDesign
import HTSDomain
import SwiftUI

/// Rank shield: letter on `rank-fill`, `khaki` for E to B, `bone` for A and S (design system, Patentes).
struct RankBadge: View {
    let rank: Rank

    var body: some View {
        Text(verbatim: rank.id.rawValue)
            .htsTextStyle(.pieceTitle)
            .foregroundStyle(color)
            .frame(width: 56, height: 56)
            .background(Color.hts.rankFill, in: NotchShape(cut: HTSNotch.sm))
            .overlay(NotchShape(cut: HTSNotch.sm).strokeBorder(color, lineWidth: HTSStroke.hair))
            .overlay(alignment: .topTrailing) {
                if rank.id == .s {
                    Image(systemName: "star.fill").font(.caption2).foregroundStyle(Color.hts.redText).padding(4)
                }
            }
            .accessibilityLabel("Patente \(rank.id.rawValue), \(rank.name)")
    }

    private var color: Color {
        switch rank.id {
        case .a, .s: Color.hts.bone
        default: Color.hts.khaki
        }
    }
}
