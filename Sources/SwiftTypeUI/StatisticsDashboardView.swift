import SwiftUI
import SwiftTypeCore

/// Dashboard view rendering real-time performance metrics, WPM boost, and keystroke savings.
public struct StatisticsDashboardView: View {
    @ObservedObject var statistics: StatisticsService

    public init(statistics: StatisticsService) {
        self.statistics = statistics
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Performance Dashboard")
                    .font(.title)
                    .fontWeight(.bold)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    StatCard(
                        title: "Keystrokes Saved",
                        value: "\(statistics.metrics.totalKeystrokesSaved)",
                        subtitle: "Characters avoided via instant correction",
                        icon: "keyboard.chevron.compact.down",
                        color: .blue
                    )
                    StatCard(
                        title: "Words Corrected",
                        value: "\(statistics.metrics.totalCorrections)",
                        subtitle: "Total automated corrections performed",
                        icon: "checkmark.seal.fill",
                        color: .green
                    )
                    StatCard(
                        title: "Estimated WPM Boost",
                        value: String(format: "+%.1f%%", statistics.metrics.estimatedWPMBoost),
                        subtitle: "Typing speed enhancement over raw speed",
                        icon: "speedometer",
                        color: .orange
                    )
                    StatCard(
                        title: "Time Saved",
                        value: formattedTimeSaved(seconds: statistics.metrics.estimatedSecondsSaved),
                        subtitle: "Cumulative typing time recovered",
                        icon: "clock.arrow.2.circlepath",
                        color: .purple
                    )
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("Engine Health & Accuracy")
                        .font(.headline)

                    HStack(spacing: 24) {
                        HealthMetric(title: "Avg Latency", value: String(format: "%.2f ms", statistics.metrics.averageLatencyMs), target: "< 5.00 ms")
                        HealthMetric(title: "Learned Words", value: "\(statistics.metrics.wordsLearned)", target: "Auto-adapted")
                        HealthMetric(title: "Cmd+Z Reversions", value: "\(statistics.metrics.falseCorrections)", target: "Low false positive")
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.1)))
                }

                Spacer()
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 620, minHeight: 500)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func formattedTimeSaved(seconds: Double) -> String {
        if seconds < 60 {
            return String(format: "%.1f sec", seconds)
        } else if seconds < 3600 {
            return String(format: "%.1f min", seconds / 60.0)
        } else {
            return String(format: "%.1f hrs", seconds / 3600.0)
        }
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
            }

            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))

            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.1)))
    }
}

private struct HealthMetric: View {
    let title: String
    let value: String
    let target: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
            Text(target)
                .font(.caption2)
                .foregroundColor(.green)
        }
    }
}
