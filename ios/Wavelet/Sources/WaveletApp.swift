import SwiftUI

@main
struct WaveletApp: App {
    @State private var selection = MetricSelection()
    @State private var syncStatus = SyncStatus()
    @State private var account = AccountStore()
    @State private var sync = HealthSync()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(selection)
                .environment(syncStatus)
                .environment(account)
                .environment(sync)
                .task {
                    await account.restoreSession()
                    syncStatus.restore(isSignedIn: account.isSignedIn)
                }
        }
    }
}
