import SwiftUI

struct RootView: View {
    @Environment(MetricSelection.self) private var selection

    var body: some View {
        if selection.hasAcceptedSharingDisclosure {
            MetricPickerView()
        } else {
            DisclosureGateView()
        }
    }
}
