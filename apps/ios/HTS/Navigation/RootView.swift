import HTSDesign
import HTSPersistence
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

    /// `-HTSOpenProgress YES` opens Progresso over the Home (screenshots).
    @State private var homePath: [Route] = UserDefaults.standard.bool(forKey: "HTSOpenProgress") ? [.progress] : []
    @State private var arcsPath: [Route] = []
    @State private var profilePath: [Route] = []
    /// Bumped when the selected tab is tapped on its first page: that page scrolls to the top (#106).
    @State private var scrollToTop: [AppTab: Int] = [:]

    var body: some View {
        // The system tab bar is hidden: Liquid Glass ignores the brand colors and adds blur, and the compatibility
        // key does not hold on every iOS version (docs/decisions/0022). TabView still keeps each tab's state.
        TabView(selection: $selection) {
            Tab(value: AppTab.home) {
                TabStack(path: $homePath) { HomeScreen() }.scrollToTopSignal(scrollToTop[.home])
                    .toolbar(.hidden, for: .tabBar)
            }
            Tab(value: AppTab.arcs) {
                TabStack(path: $arcsPath) { ArcsScreen() }.scrollToTopSignal(scrollToTop[.arcs])
                    .toolbar(.hidden, for: .tabBar)
            }
            Tab(value: AppTab.journal) {
                JournalScreen().scrollToTopSignal(scrollToTop[.journal]).toolbar(.hidden, for: .tabBar)
            }
            Tab(value: AppTab.profile) {
                TabStack(path: $profilePath) { ProfileScreen() }.scrollToTopSignal(scrollToTop[.profile])
                    .toolbar(.hidden, for: .tabBar)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { BrandTabBar(selection: $selection, onReselect: reselect) }
        // A tab left behind goes back to its first page (#98).
        .onChange(of: selection) { old, _ in
            switch old {
            case .home: homePath = []
            case .arcs: arcsPath = []
            case .profile: profilePath = []
            case .journal: break
            }
        }
        .preferredColorScheme(.dark)
        #if DEBUG
            .task(id: "\(app.athlete?.id.uuidString ?? "")-\(app.dataVersion)") { await openDemoPages() }
        #endif
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

#if DEBUG
    extension RootView {
        /// `-HTSOpenArc Forja` (and `-HTSOpenWorkout "Teste de Potência"`) open an arc on Arcos, and a workout of it
        /// (screenshots).
        fileprivate func openDemoPages() async {
            guard arcsPath.isEmpty, let name = UserDefaults.standard.string(forKey: "HTSOpenArc"),
                let database = app.database, let athlete = app.athlete
            else { return }
            let service = ArcService(database)
            let season = try? await SeasonService(database).activeSeason(athleteId: athlete.id)
            let arcs =
                ((try? await service.summaries(athleteId: athlete.id, seasonId: season?.id)) ?? [])
                + ((try? await service.summaries(athleteId: athlete.id, seasonId: nil)) ?? [])
            guard let arc = arcs.first(where: { $0.arc.name == name })?.arc else { return }
            var path: [Route] = [.arc(arc.id)]
            if let workout = UserDefaults.standard.string(forKey: "HTSOpenWorkout"),
                let template = try? await PlanRepository(database).plan(arcId: arc.id)?.templates
                    .first(where: { $0.template.name == workout })
            {
                path.append(.workout(templateId: template.template.id))
            }
            selection = .arcs
            arcsPath = path
        }
    }
#endif

extension RootView {
    /// Tapping the selected tab: pages on the stack go away; on the first page, it scrolls to the top (#106).
    fileprivate func reselect(_ tab: AppTab) {
        switch tab {
        case .home where !homePath.isEmpty: homePath = []
        case .arcs where !arcsPath.isEmpty: arcsPath = []
        case .profile where !profilePath.isEmpty: profilePath = []
        default: scrollToTop[tab, default: 0] += 1
        }
    }
}

/// Opaque `black` bar with a `line` divider: `tab-idle` for inactive tabs and `bone` for the selected one.
struct BrandTabBar: View {
    /// Height above the home indicator. Screens add it as a bottom margin: the inset on the TabView does not
    /// reach the tabs' scroll views.
    static let height: CGFloat = 49 + HTSSpacing.space1

    @Binding var selection: AppTab
    var onReselect: (AppTab) -> Void = { _ in }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                let selected = tab == selection
                Button {
                    if selected { onReselect(tab) } else { selection = tab }
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
