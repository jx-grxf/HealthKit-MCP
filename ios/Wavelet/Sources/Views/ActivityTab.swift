import SwiftUI

/// What assistants have actually read, and when.
struct ActivityTab: View {
    @Environment(AccountStore.self) private var account
    @State private var log = AccessLogStore()

    var body: some View {
        NavigationStack {
            Group {
                if !account.isSignedIn {
                    ContentUnavailableView(
                        "Not connected",
                        systemImage: "person.crop.circle.badge.exclamationmark",
                        description: Text("Sign in to see what assistants have read."))
                } else if log.entries.isEmpty && !log.isLoading {
                    ContentUnavailableView(
                        "Nothing read yet",
                        systemImage: "eye.slash",
                        description: Text("When an assistant reads your summaries, every request appears here."))
                } else {
                    list
                }
            }
            .navigationTitle("Activity")
            .refreshable { await log.reload() }
            .task { if account.isSignedIn { await log.reload() } }
        }
    }

    private var list: some View {
        List {
            Section {
                HStack(spacing: 20) {
                    StatTile(title: "Today", value: "\(log.readsToday)")
                    StatTile(title: "Total", value: "\(log.totalReads)")
                    StatTile(
                        title: "Assistants",
                        value: "\(log.clients.count)",
                        tint: .purple)
                }
            }
            .listRowBackground(Color.clear)

            Section("Requests") {
                ForEach(log.entries) { entry in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.tool)
                                .font(.system(.subheadline, design: .monospaced))
                            if let client = entry.client {
                                Text(client)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(entry.at, format: .relative(presentation: .numeric))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .animation(.smooth, value: log.entries.count)
    }
}
