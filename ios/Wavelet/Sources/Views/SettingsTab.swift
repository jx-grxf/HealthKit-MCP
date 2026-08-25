import SwiftUI

struct SettingsTab: View {
    @AppStorage("wavelet.appearance.v1") private var appearanceRaw = Appearance.system.rawValue

    private var appearance: Appearance {
        Appearance(rawValue: appearanceRaw) ?? .system
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Appearance", selection: $appearanceRaw) {
                        ForEach(Appearance.allCases) { option in
                            Label(option.title, systemImage: option.symbol).tag(option.rawValue)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("System follows your iPhone's light or dark setting.")
                }

                Section("Connection") {
                    LabeledContent("Endpoint") {
                        Text(ConnectGuideView.endpoint)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    NavigationLink("Connect an assistant") { ConnectGuideView() }
                }

                Section {
                    LabeledContent("Metrics in catalog", value: "\(MetricCatalog.available.count)")
                    LabeledContent("Version", value: appVersion)
                } header: {
                    Text("About")
                } footer: {
                    Text("Wavelet reads only the categories you switch on, summarises them on this iPhone, and never uses your health data for advertising or profiling.")
                }
            }
            .navigationTitle("Settings")
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }
}
