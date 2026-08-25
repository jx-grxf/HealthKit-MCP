import SwiftUI

/// How to connect an assistant.
///
/// The endpoint is the only thing a user has to carry across to ChatGPT or
/// Claude, so it is copyable rather than something to retype.
struct ConnectGuideView: View {
    static let endpoint = "https://mcp.johannesgrof.me/mcp"

    @State private var copied = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Address")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(Self.endpoint)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                    Button {
                        UIPasteboard.general.string = Self.endpoint
                        copied = true
                    } label: {
                        Label(copied ? "Copied" : "Copy address",
                              systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.vertical, 4)
            } footer: {
                Text("Signing in with your Apple Account is part of connecting. The assistant never sees your password, and only reads the categories you switched on.")
            }

            Section("ChatGPT") {
                step(1, "Open Settings, then Apps & Connectors.")
                step(2, "Turn on Developer mode under Advanced.")
                step(3, "Choose Create, paste the address above.")
                step(4, "Confirm, then approve the Wavelet consent screen.")
            }

            Section("Claude") {
                step(1, "Open Settings, then Connectors.")
                step(2, "Choose Add custom connector.")
                step(3, "Paste the address above and continue.")
                step(4, "Sign in with Apple and approve access.")
            }

            Section {
                step(1, "Ask: \"Which health metrics am I sharing?\"")
                step(2, "Then: \"How was my sleep last week?\"")
            } header: {
                Text("Try it")
            } footer: {
                Text("Switch a category off here and it becomes unreadable to every connected assistant immediately — you do not need to disconnect anything.")
            }
        }
        .navigationTitle("Connect an assistant")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func step(_ number: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 16, alignment: .trailing)
            Text(text)
        }
    }
}
