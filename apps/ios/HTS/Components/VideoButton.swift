import HTSDesign
import SafariServices
import SwiftUI

/// Play button beside an exercise name: opens the coach's video in a Safari sheet, without leaving the app (#110).
struct VideoButton: View {
    let url: URL
    let exerciseName: String

    @State private var showing = false

    var body: some View {
        Button {
            showing = true
        } label: {
            Image(systemName: "play.rectangle").fontWeight(.light).frame(width: 44, height: 44)
        }
        .foregroundStyle(Color.hts.bone)
        .accessibilityLabel("Ver vídeo de \(exerciseName)")
        .sheet(isPresented: $showing) {
            SafariView(url: url).ignoresSafeArea()
        }
    }
}

private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredControlTintColor = UIColor(Color.hts.bone)
        controller.preferredBarTintColor = UIColor(Color.hts.black)
        controller.overrideUserInterfaceStyle = .dark
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
