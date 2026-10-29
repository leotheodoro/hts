import HTSDesign
import SwiftUI
import UIKit

enum AppTab: String, Hashable, CaseIterable {
    case home, arcs, journal, profile

    var title: LocalizedStringKey {
        switch self {
        case .home: "Home"
        case .arcs: "Arcos"
        case .journal: "Diário"
        case .profile: "Perfil"
        }
    }

    /// Stroke icon until the brand icon set exists: SF Symbol at light weight.
    var symbol: String {
        switch self {
        case .home: "shield"
        case .arcs: "line.3.horizontal"
        case .journal: "calendar"
        case .profile: "person"
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var app
    /// `-HTSInitialTab profile` as a launch argument opens a specific tab (screenshots, UI tests).
    @State private var selection =
        UserDefaults.standard.string(forKey: "HTSInitialTab").flatMap(AppTab.init(rawValue:)) ?? .home

    @State private var homePath: [Route] = []
    @State private var arcsPath: [Route] = []

    var body: some View {
        // The system tab bar is hidden: Liquid Glass ignores the brand colors and adds blur, and the compatibility
        // key does not hold on every iOS version (docs/decisions/0022). TabView still keeps each tab's state.
        TabView(selection: $selection) {
            Tab(value: AppTab.home) { TabStack(path: $homePath) { HomeScreen() }.toolbar(.hidden, for: .tabBar) }
            Tab(value: AppTab.arcs) { TabStack(path: $arcsPath) { ArcsScreen() }.toolbar(.hidden, for: .tabBar) }
            Tab(value: AppTab.journal) { JournalScreen().toolbar(.hidden, for: .tabBar) }
            Tab(value: AppTab.profile) { ProfileScreen().toolbar(.hidden, for: .tabBar) }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { BrandTabBar(selection: $selection) }
        // A tab left behind goes back to its first page (#98).
        .onChange(of: selection) { old, _ in
            switch old {
            case .home: homePath = []
            case .arcs: arcsPath = []
            case .journal, .profile: break
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: Bindable(app).showsActiveSession) {
            if let database = app.database, let session = app.activeSession {
                ActiveSessionScreen(
                    database: database, session: session,
                    defaultRestSeconds: app.athlete?.defaultRestSeconds ?? 90
                )
                .environment(app)
            }
        }
    }
}

/// Opaque `black` bar with a `line` divider: `tab-idle` for inactive tabs and `bone` for the selected one.
struct BrandTabBar: View {
    /// Height above the home indicator. Screens add it as a bottom margin: the inset on the TabView does not
    /// reach the tabs' scroll views.
    static let height: CGFloat = 49 + HTSSpacing.space1

    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                let selected = tab == selection
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: HTSSpacing.space1) {
                        Image(systemName: tab.symbol).font(.title3).fontWeight(.light).frame(height: 24)
                        Text(tab.title).font(.custom(HTSFontFamily.body.postScriptName(weight: 500), size: 11))
                    }
                    .foregroundStyle(selected ? Color.hts.bone : Color.hts.tabIdle)
                    .frame(maxWidth: .infinity, minHeight: Self.height - HTSSpacing.space1)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(.top, HTSSpacing.space1)
        .background(Color.hts.black.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(Color.hts.line).frame(height: HTSStroke.hair) }
    }
}

#Preview {
    HTSFonts.register()
    return RootView().environment(AppModel(database: try? .inMemory(), apiConfiguration: nil))
}
