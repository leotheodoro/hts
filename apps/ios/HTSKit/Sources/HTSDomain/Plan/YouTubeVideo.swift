import Foundation

/// A YouTube link reduced to what the in-app player needs (#112): the video id, where it starts and whether it is a
/// vertical short. Accepts youtube.com/shorts, /watch?v=, /embed and youtu.be links; anything else is nil.
public struct YouTubeVideo: Hashable, Sendable {
    public let id: String
    public let start: Int?
    public let isShort: Bool

    public init?(url: URL) {
        guard let host = url.host()?.lowercased() else { return nil }
        let path = url.pathComponents.filter { $0 != "/" }
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let id: String?
        if host == "youtu.be" {
            id = path.first
        } else if host == "youtube.com" || host.hasSuffix(".youtube.com") {
            switch path.first {
            case "shorts", "embed", "live": id = path.dropFirst().first
            case "watch": id = query.first { $0.name == "v" }?.value
            default: id = nil
            }
        } else {
            id = nil
        }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        guard let id, !id.isEmpty, id.unicodeScalars.allSatisfy(allowed.contains) else { return nil }
        self.id = id
        isShort = path.first == "shorts"
        start = query.first { $0.name == "t" || $0.name == "start" }?.value
            .flatMap { Int($0.trimmingCharacters(in: CharacterSet(charactersIn: "s"))) }
    }

    /// Player URL: inline, autoplay, no related videos from other channels.
    public func embedURL(origin: String) -> URL {
        var components = URLComponents(string: "https://www.youtube.com/embed/\(id)")!
        components.queryItems =
            [
                URLQueryItem(name: "playsinline", value: "1"), URLQueryItem(name: "autoplay", value: "1"),
                URLQueryItem(name: "rel", value: "0"), URLQueryItem(name: "origin", value: origin),
            ] + (start.map { [URLQueryItem(name: "start", value: String($0))] } ?? [])
        return components.url!
    }
}
