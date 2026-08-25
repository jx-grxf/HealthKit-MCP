import SwiftUI

struct RootView: View {
    @Environment(MetricSelection.self) private var selection
    @AppStorage("wavelet.appearance.v1") private var appearanceRaw = Appearance.system.rawValue

    private var appearance: Appearance {
        Appearance(rawValue: appearanceRaw) ?? .system
    }

    var body: some View {
        Group {
            if selection.hasAcceptedSharingDisclosure {
                MainTabs()
            } else {
                DisclosureGateView()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .animation(.smooth, value: selection.hasAcceptedSharingDisclosure)
        // nil when following the system.
        .preferredColorScheme(appearance.colorScheme)
    }
}

private struct MainTabs: View {
    // `Tab` is a SwiftUI type; naming the enum that shadowed it.
    private enum Screen: Hashable { case overview, categories, activity, settings }

    @State private var screen = Screen.overview

    var body: some View {
        // The `Tab { }` builder is iOS 18+. This form works from iOS 17 and
        // still picks up the Liquid Glass tab bar on iOS 26.
        TabView(selection: $screen) {
            OverviewTab()
                .tabItem { Label("Overview", systemImage: "waveform.path.ecg") }
                .tag(Screen.overview)
            MetricPickerView()
                .tabItem { Label("Categories", systemImage: "square.grid.2x2") }
                .tag(Screen.categories)
            ActivityTab()
                .tabItem { Label("Activity", systemImage: "eye") }
                .tag(Screen.activity)
            SettingsTab()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(Screen.settings)
        }
    }
}
