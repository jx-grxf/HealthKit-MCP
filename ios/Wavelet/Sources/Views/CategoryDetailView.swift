import SwiftUI

struct CategoryDetailView: View {
    let category: MetricCategory
    @Environment(MetricSelection.self) private var selection

    private var metrics: [MetricDescriptor] { MetricCatalog.inCategory(category) }
    private var bulkEnabled: [MetricDescriptor] {
        metrics.filter { $0.sensitivity == .standard }
    }
    private var hasSensitive: Bool { metrics.contains { $0.sensitivity == .sensitive } }

    var body: some View {
        List {
            Section {
                ForEach(metrics) { metric in
                    MetricToggleRow(metric: metric)
                }
            } footer: {
                if hasSensitive {
                    Text("Sensitive categories are never included in \"Enable all\" and must be switched on individually.")
                }
            }
        }
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Enable all", systemImage: "checkmark.circle") {
                        selection.enableAll(in: category)
                    }
                    .disabled(bulkEnabled.allSatisfy(selection.isEnabled))
                    Button("Turn off all", systemImage: "slash.circle", role: .destructive) {
                        selection.disableAll(in: category)
                    }
                    .disabled(selection.enabledCount(in: category) == 0)
                } label: {
                    Label("Enable all", systemImage: "ellipsis.circle")
                }
            }
        }
    }
}

struct MetricToggleRow: View {
    let metric: MetricDescriptor
    @Environment(MetricSelection.self) private var selection

    var body: some View {
        Toggle(isOn: .init(
            get: { selection.isEnabled(metric) },
            set: { selection.setEnabled($0, for: metric) })
        ) {
            VStack(alignment: .leading, spacing: 3) {
                Text(metric.localizedName)
                HStack(spacing: 6) {
                    if let unit = metric.unit {
                        Text(unit)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if metric.sensitivity == .sensitive {
                        Text("Sensitive")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.orange.opacity(0.18), in: Capsule())
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
    }
}
