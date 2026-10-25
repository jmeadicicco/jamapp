import SwiftData
import SwiftUI

@main
struct JamApp: App {
    @State private var sync = SyncEngine()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(sync)
        }
        .modelContainer(for: [Item.self, Person.self])
    }
}
