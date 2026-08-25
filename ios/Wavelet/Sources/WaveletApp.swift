import SwiftUI

@main
struct WaveletApp: App {
    @State private var selection = MetricSelection()
    @State private var syncStatus = SyncStatus()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(selection)
                .environment(syncStatus)
        }
    }
}
