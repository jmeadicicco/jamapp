import SwiftData
import SwiftUI

/// Connection status for each source, with a button to grant access.
struct SourcesView: View {
    @Environment(SyncEngine.self) private var sync
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Source.allCases) { source in
                        row(for: source)
                    }
                } footer: {
                    if let lastSync = sync.lastSync {
                        Text("Last synced \(lastSync.formatted(.relative(presentation: .named)))")
                    }
                }
                Section("Coming later") {
                    ForEach(Source.planned, id: \.title) { planned in
                        LabeledContent {
                            Text("Phase \(planned.phase)")
                        } label: {
                            Label(planned.title, systemImage: planned.systemImage)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                if let error = sync.lastError {
                    Section("Last error") { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Sources")
            .toolbar {
                Button("Sync", systemImage: "arrow.clockwise") {
                    Task { await sync.syncAll(context: context) }
                }
                .disabled(sync.isSyncing)
            }
        }
    }

    @ViewBuilder
    private func row(for source: Source) -> some View {
        let state = sync.access[source] ?? .notDetermined
        LabeledContent {
            switch state {
            case .notDetermined:
                Button("Connect") { Task { await sync.connect(source, context: context) } }
                    .buttonStyle(.borderedProminent)
            case .denied:
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
            case .granted, .limited:
                Text(state.label)
            }
        } label: {
            Label(source.title, systemImage: source.systemImage)
        }
    }
}
