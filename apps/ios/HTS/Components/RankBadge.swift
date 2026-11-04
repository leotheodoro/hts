import HTSDesign
import HTSDomain
import SwiftUI

/// Rank shield: letter on `rank-fill`, `khaki` for E to B, `bone` for A and S (design system, Patentes).
struct RankBadge: View {
    let rank: Rank
    /// The small shield of the rank ladder on the Progresso page.
    var compact = false

    var body: some View {
        // The piece-title font without its 34 pt line and tracking: a lone capital in the font's natural line
        // box has its caps centered, while the shorter line trims only the bottom and pushes it down (#193).
        Text(verbatim: rank.id.rawValue)
            .font(.hts(compact ? .pieceSub : .pieceTitle))
            .foregroundStyle(color)
            .frame(width: compact ? 32 : 56, height: compact ? 32 : 56)
            .background(Color.hts.rankFill, in: NotchShape(cut: HTSNotch.sm))
            .overlay(NotchShape(cut: HTSNotch.sm).strokeBorder(color, lineWidth: HTSStroke.hair))
            .overlay(alignment: .topTrailing) {
                if rank.id == .s, !compact {
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
