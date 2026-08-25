import SwiftUI

/// Status at a glance: is it connected, is it syncing, how much is shared.
struct OverviewTab: View {
    @Environment(MetricSelection.self) private var selection
    @Environment(SyncStatus.self) private var status
    @Environment(AccountStore.self) private var account
    @Environment(HealthSync.self) private var sync

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    GlassCard { SyncStatusCard(status: status) }

                    GlassCard {
                        HStack(spacing: 20) {
                            StatTile(
                                title: "Shared",
                                value: "\(selection.enabledCount)",
                                caption: "of \(MetricCatalog.available.count)")
                            StatTile(
                                title: "Health access",
                                value: status.hasRequestedHealthAccess ? "✓" : "—",
                                tint: status.hasRequestedHealthAccess ? .green : .secondary)
                        }
                    }

                    if account.isSignedIn {
                        Button {
                            Task {
                                await sync.run(
                                    selection: selection, account: account, status: status)
                            }
                        } label: {
                            Label(
                                status.isSyncing ? "Syncing…" : "Sync now",
                                systemImage: "arrow.triangle.2.circlepath",
                            )
                            .frame(maxWidth: .infinity)
                            // .rotate needs iOS 18; .pulse works from 17.
                            .symbolEffect(.pulse, isActive: status.isSyncing)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(selection.enabledCount == 0 || status.isSyncing)
                    }

                    NavigationLink {
                        ConnectGuideView()
                    } label: {
                        GlassCard {
                            HStack {
                                Label("Connect an assistant", systemImage: "link")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    GlassCard { AccountPanel() }
                }
                .padding(16)
                .animation(.smooth, value: status.isSyncing)
                .animation(.smooth, value: selection.enabledCount)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Wavelet")
        }
    }
}
