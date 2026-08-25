import SwiftUI

/// Third-party AI sharing disclosure.
///
/// App Review guideline 5.1.2(i) requires disclosing that personal data goes to
/// third-party AI and obtaining permission *before* it does. 5.1.3 additionally
/// forbids any advertising or data-mining use of HealthKit data. Naming the
/// assistants explicitly is the point — "AI services" in the abstract is what
/// gets rejected.
struct DisclosureGateView: View {
    @Environment(MetricSelection.self) private var selection

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Before you share anything")
                    .font(.largeTitle.bold())

                point(
                    "You choose every category",
                    "Nothing is read from Health until you switch it on. Everything starts off.")
                point(
                    "Assistants you connect can read what you share",
                    "That means ChatGPT, Claude, and any other assistant you connect. They receive daily summaries — never your raw Health records.")
                point(
                    "Summaries only",
                    "Wavelet totals each day on your iPhone and syncs the totals. Individual measurements never leave the device.")
                point(
                    "Never for advertising",
                    "Your health data is never used for advertising, marketing, or profiling, and is never sold.")
                point(
                    "You can stop at any time",
                    "Switch a category off and it stops syncing and becomes unreadable to assistants immediately.")

                Button {
                    selection.hasAcceptedSharingDisclosure = true
                } label: {
                    Text("I understand — choose what to share")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 8)
            }
            .padding(24)
        }
    }

    private func point(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(body).font(.subheadline).foregroundStyle(.secondary)
        }
    }
}
