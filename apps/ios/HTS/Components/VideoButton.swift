import HTSDesign
import HTSDomain
import SafariServices
import SwiftUI
import WebKit

/// Play button beside an exercise name. A YouTube link plays right away in an embedded player, without leaving the
/// app (#112); any other link opens in a Safari sheet.
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
            if let video = YouTubeVideo(url: url) {
                VideoPlayerSheet(video: video, exerciseName: exerciseName)
            } else {
                SafariView(url: url).ignoresSafeArea()
            }
        }
    }
}

private struct VideoPlayerSheet: View {
    let video: YouTubeVideo
    let exerciseName: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: HTSSpacing.space4) {
            HStack(spacing: HTSSpacing.space2) {
                Text(verbatim: exerciseName).htsTextStyle(.uiSection).foregroundStyle(Color.hts.bone).lineLimit(2)
                Spacer(minLength: 0)
                IconButton(symbol: "xmark", label: "Fechar vídeo") { dismiss() }
            }
            YouTubePlayer(video: video)
                .aspectRatio(video.isShort ? 9 / 16 : 16 / 9, contentMode: .fit)
                .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, HTSSpacing.space5)
        .padding(.top, HTSSpacing.space4)
        .presentationBackground(Color.hts.black)
        .preferredColorScheme(.dark)
    }
}

/// The YouTube embed in a web view. It is loaded from an HTML page with an https origin: YouTube refuses to play
/// an embed without a referrer. Navigation away from the player (logo, title, suggestions) is blocked.
private struct YouTubePlayer: UIViewRepresentable {
    /// YouTube asks embedded players in apps to identify themselves by the bundle id.
    static let origin = "https://com.hardtosubmit.app"

    let video: YouTubeVideo

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        let html = """
            <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
            <style>html,body{margin:0;height:100%;background:transparent}
            iframe{position:absolute;inset:0;width:100%;height:100%;border:0}</style></head>
            <body><iframe src="\(video.embedURL(origin: Self.origin).absoluteString)"
            allow="autoplay; encrypted-media; picture-in-picture; fullscreen" allowfullscreen
            referrerpolicy="strict-origin-when-cross-origin"></iframe></body></html>
            """
        webView.loadHTMLString(html, baseURL: URL(string: Self.origin))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        func webView(
            _ webView: WKWebView, decidePolicyFor action: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
            // The page itself and everything inside the player frame load; the main frame never leaves the page.
            guard let frame = action.targetFrame, frame.isMainFrame else {
                return action.targetFrame == nil ? .cancel : .allow
            }
            return action.request.url?.absoluteString.hasPrefix(YouTubePlayer.origin) == true ? .allow : .cancel
        }

        /// Links that ask for a new window (open on YouTube) are dropped.
        func webView(
            _ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
            for action: WKNavigationAction, windowFeatures: WKWindowFeatures
        ) -> WKWebView? { nil }
    }
}

private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.overrideUserInterfaceStyle = .dark
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
