import HTSDesign
import HTSDomain
import SwiftUI
import UIKit

/// Fixed footer with the rest countdown, bar, −15 s, +15 s and Pular.
struct RestFooter: View {
    let model: ActiveSessionModel

    var body: some View {
        if let rest = model.rest {
            TimelineView(.periodic(from: .now, by: 0.25)) { context in
                VStack(spacing: HTSSpacing.space3) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: HTSSpacing.space1) {
                            Text("DESCANSO").htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                            Text(verbatim: model.restExerciseName).htsTextStyle(.caption)
                                .foregroundStyle(Color.hts.greyApp).lineLimit(1)
                        }
                        Spacer()
                        Text(verbatim: RestTimer.format(rest.remaining(at: context.date)))
                            .htsTextStyle(.uiDisplay).foregroundStyle(Color.hts.bone)
                            .accessibilityLabel("Descanso restante")
                    }
                    ProgressBar(value: rest.progress(at: context.date))
                    HStack(spacing: HTSSpacing.space2) {
                        footerButton("−15 s") { model.adjustRest(by: -RestTimer.step) }
                        footerButton("+15 s") { model.adjustRest(by: RestTimer.step) }
                        footerButton("Pular") { model.skipRest() }
                    }
                }
                .onChange(of: rest.isFinished(at: context.date)) { _, finished in
                    guard finished else { return }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    model.restDidFinish()
                }
            }
            .padding(.horizontal, HTSSpacing.space5)
            .padding(.vertical, HTSSpacing.space4)
            .background(Color.hts.surface)
            .overlay(alignment: .top) { Rectangle().fill(Color.hts.line).frame(height: HTSStroke.hair) }
        }
    }

    private func footerButton(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).htsTextStyle(.bodyStrong).frame(maxWidth: .infinity, minHeight: 44)
        }
        .foregroundStyle(Color.hts.bone)
        .overlay(Rectangle().strokeBorder(Color.hts.lineStrong, lineWidth: HTSStroke.hair))
    }
}
