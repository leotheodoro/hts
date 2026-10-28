import HTSDesign
import SwiftUI

@main
struct HTSApp: App {
    var body: some Scene {
        WindowGroup {
            Text("HTS")
                .foregroundStyle(Color.hts.bone)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.hts.black)
        }
    }
}
