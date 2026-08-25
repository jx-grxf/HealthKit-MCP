import SwiftUI

/// Card styling that adopts Liquid Glass where the OS has it.
///
/// Gated rather than made the deployment target: the app supports iOS 17, and
/// forcing 26 to get one material would drop every older device for no
/// functional gain.
struct GlassCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        if #available(iOS 26.0, *) {
            content
                .padding(16)
                .glassEffect(.regular, in: .rect(cornerRadius: 20))
        } else {
            content
                .padding(16)
                .background(.background.secondary, in: .rect(cornerRadius: 20))
        }
    }
}
