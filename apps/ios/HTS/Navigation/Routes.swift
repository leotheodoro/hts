import SwiftUI

/// Pages pushed inside the Home and Arcos tabs.
enum Route: Hashable {
    case arc(UUID)
    case workout(templateId: UUID)
}

/// Navigation stack of a tab. The system bar stays hidden like the tab bar (docs/decisions/0022); pages draw their
/// own back button.
struct TabStack<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        NavigationStack {
            content
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: Route.self) { route in
                    Group {
                        switch route {
                        case .arc(let id): ArcDetailScreen(arcId: id)
                        case .workout(let id): WorkoutScreen(templateId: id)
                        }
                    }
                    .toolbar(.hidden, for: .navigationBar)
                }
        }
    }
}
