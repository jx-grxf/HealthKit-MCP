import SwiftUI

struct SyncStatusCard: View {
    let status: SyncStatus

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: status.symbol)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(status.title).font(.headline)
                if !status.detail.isEmpty {
                    Text(status.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var color: Color {
        switch status.tint {
        case .secondary: .secondary
        case .good: .green
        case .bad: .orange
        }
    }
}
