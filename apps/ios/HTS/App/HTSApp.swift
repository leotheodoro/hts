import HTSDesign
import SwiftUI

@main
struct HTSApp: App {
    @State private var model = AppModel.live()

    init() {
        HTSFonts.register()
        TabBarAppearance.apply()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .task { await model.start() }
        }
    }
}
