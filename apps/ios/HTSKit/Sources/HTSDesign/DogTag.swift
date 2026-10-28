import SwiftUI

/// Personal record plate: rounded metal tag (`radius-tag`, the only curve outside the patch) with a hole and mono
/// text in `tag-ink`.
public struct DogTag: View {
    private let lines: [String]

    public init(lines: [String]) {
        self.lines = lines
    }

    public var body: some View {
        HStack(alignment: .center, spacing: HTSSpacing.space3) {
            Circle()
                .fill(Color.hts.black)
                .frame(width: 10, height: 10)
                .overlay(Circle().strokeBorder(Color.hts.tagEdge, lineWidth: HTSStroke.hair))
            VStack(alignment: .leading, spacing: HTSSpacing.space1) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    Text(verbatim: line)
                        .htsTextStyle(index == 0 ? .label : .dataSm)
                        .foregroundStyle(Color.hts.tagInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, HTSSpacing.space4)
        .padding(.vertical, HTSSpacing.space3)
        .background(Color.hts.tag, in: RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28 - 4).strokeBorder(Color.hts.tagEdge, lineWidth: HTSStroke.hair)
                .padding(4)
        )
    }
}

#Preview {
    DogTag(lines: ["ZERCHER SQUAT", "070.0 KG × 03", "27.10.26 · TR 13"])
        .padding()
        .background(Color.hts.black)
}
