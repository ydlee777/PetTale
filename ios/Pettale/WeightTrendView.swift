import Charts
import SwiftUI

struct WeightTrendView: View {
    let pet: Pet
    let recordAction: () -> Void

    @State private var period: WeightPeriod = .threeMonths

    private var trend: WeightTrend {
        WeightTrendPresentation.trend(for: pet, period: period)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                currentWeight

                if trend.allObservations.isEmpty {
                    emptyState
                } else {
                    periodSelector
                    periodContent
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Weight")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var currentWeight: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Current Weight")
                .font(.headline)
                .foregroundStyle(.secondary)
            if let current = trend.current {
                Text(WeightTrendPresentation.formattedKilograms(current.kilograms))
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .accessibilityLabel(
                        String(localized: "Current Weight: \(WeightTrendPresentation.formattedKilograms(current.kilograms))")
                    )
            } else {
                Text("—")
                    .font(.largeTitle.bold())
            }
        }
    }

    private var periodSelector: some View {
        Picker("Period", selection: $period) {
            ForEach(WeightPeriod.allCases) { item in
                Text(item.shortLabel)
                    .tag(item)
                    .accessibilityLabel(item.accessibilityLabel)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Weight history period")
    }

    @ViewBuilder
    private var periodContent: some View {
        if trend.visibleObservations.isEmpty {
            unavailableState(
                title: "No weight records in this period",
                description: "Choose a longer period to see earlier records.",
                symbolName: "calendar.badge.exclamationmark"
            )
        } else if trend.visibleObservations.count == 1 {
            singleObservation
        } else {
            chart
            changeSummary
        }
    }

    private var chart: some View {
        Chart(trend.visibleObservations) { observation in
            LineMark(
                x: .value("Date", observation.occurredAt),
                y: .value("Weight", observation.kilograms)
            )
            .interpolationMethod(.linear)
            PointMark(
                x: .value("Date", observation.occurredAt),
                y: .value("Weight", observation.kilograms)
            )
        }
        .chartYScale(domain: trend.yDomain ?? 0...1)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(.clear)
                AxisTick()
                AxisValueLabel(format: xAxisFormat)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) {
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .frame(height: 250)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
        .accessibilityLabel("Weight history chart")
        .accessibilityValue(chartAccessibilityValue)
    }

    private var xAxisFormat: Date.FormatStyle {
        switch period {
        case .oneMonth, .threeMonths:
            .dateTime.month(.abbreviated).day()
        case .sixMonths, .oneYear, .all:
            .dateTime.month(.abbreviated).year(.twoDigits)
        }
    }

    private var chartAccessibilityValue: String {
        guard let first = trend.visibleObservations.first, let last = trend.visibleObservations.last else { return "" }
        return String(localized: "\(trend.visibleObservations.count) records, from \(WeightTrendPresentation.formattedKilograms(first.kilograms)) to \(WeightTrendPresentation.formattedKilograms(last.kilograms))")
    }

    private var changeSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Change")
                .font(.headline)
                .foregroundStyle(.secondary)
            if let change = trend.changeKilograms {
                Text(WeightTrendPresentation.formattedChange(change))
                    .font(.title2.bold())
                    .accessibilityLabel(String(localized: "Weight change: \(WeightTrendPresentation.formattedChange(change))"))
            }
        }
    }

    private var singleObservation: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("One weight record", systemImage: "scalemass")
                .font(.headline)
            Text("Add another weight record to see the trend.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "scalemass")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("No weight history yet")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("Tell Pettale your pet's weight when you record today's story.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Record", systemImage: "mic.fill", action: recordAction)
                .buttonStyle(.borderedProminent)
                .accessibilityHint(String(localized: "Starts a new voice record for \(pet.name)"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private func unavailableState(
        title: LocalizedStringKey,
        description: LocalizedStringKey,
        symbolName: String
    ) -> some View {
        VStack(spacing: 12) {
            Image(systemName: symbolName)
                .font(.title)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
            Text(description)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}
