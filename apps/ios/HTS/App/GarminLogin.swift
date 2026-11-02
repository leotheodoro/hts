import Foundation

/// The end of the Garmin login (#168): the API's callback sends the browser to
/// `hardtosubmit://integrations/garmin?status=…`, which the web authentication session hands back to the app.
enum GarminLogin {
    static let callbackScheme = "hardtosubmit"

    enum Status: Equatable {
        case connected
        /// The athlete declined on the Garmin page.
        case denied
        case failed
    }

    static func status(from url: URL) -> Status {
        switch URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
            .first(where: { $0.name == "status" })?.value
        {
        case "connected": .connected
        case "denied": .denied
        default: .failed
        }
    }
}
