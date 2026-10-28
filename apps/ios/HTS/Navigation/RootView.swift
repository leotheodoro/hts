import HTSDesign
import SwiftUI
import UIKit

enum AppTab: String, Hashable {
    case status, arcs, journal, profile
}

struct RootView: View {
    @Environment(AppModel.self) private var app
    /// `-HTSInitialTab profile` as a launch argument opens a specific tab (screenshots, UI tests).
    @State private var selection =
        UserDefaults.standard.string(forKey: "HTSInitialTab").flatMap(AppTab.init(rawValue:)) ?? .status

    var body: some View {
        TabView(selection: $selection) {
            Tab(value: AppTab.status) {
                StatusScreen()
            } label: {
                TabLabel(title: "Status", symbol: "shield")
            }
            Tab(value: AppTab.arcs) {
                ArcsScreen()
            } label: {
                TabLabel(title: "Arcos", symbol: "line.3.horizontal")
            }
            Tab(value: AppTab.journal) {
                JournalScreen()
            } label: {
                TabLabel(title: "Diário", symbol: "calendar")
            }
            Tab(value: AppTab.profile) {
                ProfileScreen()
            } label: {
                TabLabel(title: "Perfil", symbol: "person")
            }
        }
        .tint(Color.hts.bone)
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: Bindable(app).showsActiveSession) {
            if let database = app.database, let session = app.activeSession {
                ActiveSessionScreen(database: database, session: session)
                    .environment(app)
            }
        }
    }
}

/// Stroke icon until the brand icon set exists: SF Symbol at light weight.
private struct TabLabel: View {
    let title: LocalizedStringKey
    let symbol: String

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(uiImage: TabBarAppearance.icon(symbol))
        }
    }
}

enum TabBarAppearance {
    static func icon(_ name: String) -> UIImage {
        let config = UIImage.SymbolConfiguration(weight: .light)
        return UIImage(systemName: name, withConfiguration: config) ?? UIImage()
    }

    /// Opaque black bar, `tab-idle` for inactive items and `bone` for the selected one. No blur, no shadow.
    @MainActor static func apply() {
        let idle = UIColor(Color.hts.tabIdle)
        let selected = UIColor(Color.hts.bone)
        let font =
            UIFont(name: HTSFontFamily.body.postScriptName(weight: 500), size: 11)
            ?? .systemFont(ofSize: 11, weight: .medium)

        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.hts.black)
        appearance.shadowColor = UIColor(Color.hts.line)
        for layout in [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance] {
            layout.normal.iconColor = idle
            layout.normal.titleTextAttributes = [.foregroundColor: idle, .font: font]
            layout.selected.iconColor = selected
            layout.selected.titleTextAttributes = [.foregroundColor: selected, .font: font]
        }
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

#Preview {
    HTSFonts.register()
    return RootView().environment(AppModel(database: try? .inMemory(), apiConfiguration: nil))
}
