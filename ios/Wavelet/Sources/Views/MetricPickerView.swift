import SwiftUI

/// Category overview. The full catalog is far too long for one flat list, so
/// categories are the top level and each opens its own toggle list.
struct MetricPickerView: View {
    @Environment(MetricSelection.self) private var selection
    @Environment(SyncStatus.self) private var status
    @State private var access = HealthAccess()
    @State private var search = ""
    @State private var authorizationError: String?

    private var categories: [MetricCategory] {
        MetricCategory.allCases.filter { !MetricCatalog.inCategory($0).isEmpty }
            .sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
    }

    private var searchResults: [MetricDescriptor] {
        guard !search.isEmpty else { return [] }
        return MetricCatalog.available
            .filter { $0.localizedName.localizedCaseInsensitiveContains(search) }
            .sorted { $0.localizedName.localizedCompare($1.localizedName) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            List {
                if search.isEmpty {
                    Section("Sync") {
                        SyncStatusCard(status: status)
                    }

                    Section {
                        LabeledContent("Selected") {
                            Text(
                                "\(selection.enabledCount) / \(MetricCatalog.available.count)"
                            )
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        }
                        LabeledContent("Health access") {
                            Text(status.hasRequestedHealthAccess
                                 ? "Requested" : "Not requested yet")
                                .foregroundStyle(.secondary)
                        }
                        Button("Authorize") {
                            Task { await authorize() }
                        }
                        .disabled(selection.enabledCount == 0)
                    } footer: {
                        Text("iOS never reveals whether read access was granted. Wavelet shows what it can actually read once data arrives.")
                    }

                    Section("Categories") {
                        ForEach(categories) { category in
                            NavigationLink {
                                CategoryDetailView(category: category)
                            } label: {
                                categoryRow(category)
                            }
                        }
                    }
                } else {
                    ForEach(searchResults) { metric in
                        MetricToggleRow(metric: metric)
                    }
                }
            }
            .searchable(text: $search, prompt: "Search health categories")
            .navigationTitle("Wavelet")
            .alert(
                "Couldn't ask for access",
                isPresented: .init(
                    get: { authorizationError != nil },
                    set: { if !$0 { authorizationError = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(authorizationError ?? "")
            }
        }
    }

    private func categoryRow(_ category: MetricCategory) -> some View {
        let total = MetricCatalog.inCategory(category).count
        let on = selection.enabledCount(in: category)
        return HStack(spacing: 12) {
            Image(systemName: category.symbol)
                .font(.body)
                .foregroundStyle(.tint)
                .frame(width: 26)
            Text(category.title)
            Spacer()
            Text(on == 0 ? "\(total)" : "\(on) / \(total)")
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(on == 0 ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
        }
    }

    private func authorize() async {
        do {
            try await access.requestAuthorization(for: selection.enabledMetrics)
            status.hasRequestedHealthAccess = true
        } catch {
            authorizationError = error.localizedDescription
        }
    }
}
