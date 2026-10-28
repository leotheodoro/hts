import HTSDesign
import SwiftUI
import UserNotifications

@main
struct HTSApp: App {
    @State private var model = AppModel.live()

    init() {
        HTSFonts.register()
        TabBarAppearance.apply()
        UNUserNotificationCenter.current().delegate = ForegroundNotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .task { await model.start() }
        }
    }
}
