import SwiftUI

/// Pages pushed inside the Home, Arcos and Perfil tabs.
enum Route: Hashable {
    case arc(UUID)
    case workout(templateId: UUID)
    case account
    case trainingSettings
    case battle
    case titles
    case attributes
    case integrations
}

/// Navigation stack of a tab. The system bar stays hidden like the tab bar (docs/decisions/0022); pages draw their
/// own back button.
struct TabStack<Content: View>: View {
    @Binding var path: [Route]
    @ViewBuilder let content: Content

    var body: some View {
        NavigationStack(path: $path) {
            content
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: Route.self) { route in
                    Group {
                        switch route {
                        case .arc(let id): ArcDetailScreen(arcId: id)
                        case .workout(let id): WorkoutScreen(templateId: id)
                        case .account: AccountScreen()
                        case .trainingSettings: TrainingSettingsScreen()
                        case .battle: BattleScreen()
                        case .titles: TitlesScreen()
                        case .attributes: AttributesScreen()
                        case .integrations: IntegrationsScreen()
                        }
                    }
                    .toolbar(.hidden, for: .navigationBar)
                }
        }
    }
}
