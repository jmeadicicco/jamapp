import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(SyncEngine.self) private var sync
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            Tab("Today", systemImage: "sun.max") { TodayView() }
            Tab("People", systemImage: "person.2") { PeopleView() }
            Tab("Sources", systemImage: "square.stack.3d.up") { SourcesView() }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active {
                Task { await sync.syncAll(context: context) }
            }
        }
    }
}
