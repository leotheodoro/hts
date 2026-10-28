import CoreText
import Foundation

/// Bundled fonts (Google Fonts, OFL). Registered from the package bundle, so the app's Info.plist needs no
/// `UIAppFonts` entry.
public enum HTSFonts {
    static let files = [
        "BigShouldersStencilDisplay-Black",
        "BigShouldersDisplay-ExtraBold",
        "BigShouldersDisplay-Black",
        "InterTight-SemiBold",
        "Inter-Regular",
        "Inter-Medium",
        "IBMPlexMono-Medium",
        "IBMPlexMono-SemiBold",
        "NotoSerifJP-Black",
    ]

    /// Registers every bundled font for this process. Safe to call more than once.
    /// Returns the files that failed to register; empty means success.
    @discardableResult
    public static func register() -> [String] { registration }

    private static let registration: [String] = files.filter { file in
        guard let url = Bundle.module.url(forResource: file, withExtension: "ttf") else { return true }
        var error: Unmanaged<CFError>?
        if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) { return false }
        let code = error.map { CFErrorGetCode($0.takeRetainedValue()) }
        return code != CTFontManagerError.alreadyRegistered.rawValue
    }
}

extension HTSFontFamily {
    /// PostScript names of the bundled weights. Unknown weights fall back to the nearest bundled one.
    var weights: [Int: String] {
        switch self {
        case .stencil: [900: "BigShouldersStencilDisplay-Black"]
        case .display: [800: "BigShouldersDisplay-ExtraBold", 900: "BigShouldersDisplay-Black"]
        case .ui: [600: "InterTight-SemiBold"]
        case .body: [400: "Inter-Regular", 500: "Inter-Medium"]
        case .mono: [500: "IBMPlexMono-Medium", 600: "IBMPlexMono-SemiBold"]
        case .kanji: [900: "NotoSerifJP-Black"]
        }
    }

    public func postScriptName(weight: Int) -> String {
        if let exact = weights[weight] { return exact }
        let nearest = weights.keys.min { abs($0 - weight) < abs($1 - weight) }
        return nearest.flatMap { weights[$0] } ?? "Inter-Regular"
    }
}
