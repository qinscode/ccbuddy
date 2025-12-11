import SwiftUI
import AppKit
import Charts

struct PopoverView: View {
    @ObservedObject var viewModel: UsageViewModel
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedHistoryRange: UsageHistoryRange = .daily

    var body: some View {
        ZStack {
            // True Glass Background using VisualEffectView
            VisualEffectView(
                material: visualEffectMaterial,
                blendingMode: .behindWindow
            )

            // Content overlay with adjustable opacity
            Color(NSColor.windowBackgroundColor)
                .opacity(1.0 - viewModel.glassOpacity)

            // Top highlight
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [
                        Color.white.opacity(colorScheme == .dark ? 0.08 : 0.3),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 50)
                Spacer()
            }

            // Main Content
            VStack(spacing: 0) {
                // Header
                headerSection
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 10)

                // Subtle Divider
                Rectangle()
                    .fill(Color.primary.opacity(0.1))
                    .frame(height: 0.5)

                // Mode-specific content
                if viewModel.usageMode == .proMax {
                    proMaxContent
                } else {
                    apiContent
                }

                // Usage Charts
                chartsSection

                // Subtle Divider
                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(height: 0.5)
                    .padding(.horizontal, 10)
                    .padding(.top, 4)

                // Action Buttons
                actionButtons
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 14)
            }
        }
        .frame(width: 320)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.15 : 0.3), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
    }

    // MARK: - Visual Effect Material

    private var visualEffectMaterial: NSVisualEffectView.Material {
        switch viewModel.materialStyle {
        case .ultraThin:
            return .hudWindow
        case .thin:
            return .popover
        case .regular:
            return .menu
        case .thick:
            return .sidebar
        case .ultraThick:
            return .windowBackground
        }
    }

    // MARK: - Pro/Max Mode Content

    private var proMaxContent: some View {
        VStack(spacing: 0) {
            // Progress Section
            progressSection
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            // Stats Section
            VStack(spacing: 10) {
                StatRow(icon: "doc.text.fill", color: .blue, title: "Tokens Used", value: viewModel.currentStats.formattedTotalTokens, fontSize: viewModel.fontSize)
                StatRow(icon: "dollarsign.circle.fill", color: .green, title: "Session Cost", value: viewModel.formattedCost, fontSize: viewModel.fontSize)
                StatRow(icon: "clock.fill", color: .cyan, title: "Time Remaining", value: viewModel.currentStats.formattedTimeRemaining, fontSize: viewModel.fontSize)
                StatRow(icon: "arrow.up.right.circle.fill", color: .orange, title: "Projected Cost", value: viewModel.formattedProjectedCost, fontSize: viewModel.fontSize)
                StatRow(icon: "flame.fill", color: .red, title: "Burn Rate", value: viewModel.currentStats.formattedBurnRate, fontSize: viewModel.fontSize)

                VStack(spacing: 4) {
                    ForEach(Array(modelDisplayList.enumerated()), id: \.element) { index, modelName in
                        if index == 0 {
                            StatRow(icon: "cpu.fill", color: .purple, title: "Model", value: modelName, fontSize: viewModel.fontSize)
                        } else {
                            StatRowNoIcon(value: modelName, fontSize: viewModel.fontSize)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    // MARK: - API Mode Content

    private var apiContent: some View {
        VStack(spacing: 10) {
            StatRow(icon: "doc.text.fill", color: .blue, title: "Tokens Used", value: viewModel.currentStats.formattedTotalTokens, fontSize: viewModel.fontSize)
            StatRow(icon: "clock.fill", color: .cyan, title: "Today", value: viewModel.formattedTodayCost, fontSize: viewModel.fontSize)
            StatRow(icon: "calendar", color: .orange, title: "This Week", value: viewModel.formattedWeekCost, fontSize: viewModel.fontSize)
            StatRow(icon: "calendar.badge.clock", color: .pink, title: "This Month", value: viewModel.formattedMonthCost, fontSize: viewModel.fontSize)
            StatRow(icon: "dollarsign.circle.fill", color: .green, title: "All Time", value: viewModel.formattedAllTimeCost, fontSize: viewModel.fontSize)

            VStack(spacing: 4) {
                ForEach(Array(modelDisplayList.enumerated()), id: \.element) { index, modelName in
                    if index == 0 {
                        StatRow(icon: "cpu.fill", color: .purple, title: "Model", value: modelName, fontSize: viewModel.fontSize)
                    } else {
                        StatRowNoIcon(value: modelName, fontSize: viewModel.fontSize)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Model Display List

    private var modelDisplayList: [String] {
        let models = viewModel.currentStats.modelsUsed
            .filter { !$0.contains("synthetic") }  // Filter out synthetic models
        if models.isEmpty { return [] }
        let uniqueNames = Set(models.map { ModelPricing.displayName(for: $0) })
        return uniqueNames.sorted()
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 8) {
            // App Icon
            if let logo = Image.loadLogo(named: "logo-64") {
                logo
                    .resizable()
                    .renderingMode(.original)
                    .frame(width: 30, height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            } else {
                HStack(spacing: 1.5) {
                    ForEach(0..<3, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color.blue.opacity(1.0 - Double(index) * 0.3))
                            .frame(width: 4, height: CGFloat(16 - index * 4))
                    }
                }
            }

            Text("CCBuddy")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)

            // Mode badge
            Text(viewModel.usageMode == .proMax ? "Pro" : "API")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(viewModel.usageMode == .proMax ? Color.blue : Color.green)
                )

            Spacer()

            Text(viewModel.formattedLastUpdated)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Session Progress")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(String(format: "%.0f%%", viewModel.currentStats.usagePercentage))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(progressColor)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.primary.opacity(0.1))
                        .frame(height: 5)

                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(progressColor)
                        .frame(
                            width: max(0, geometry.size.width * CGFloat(min(viewModel.currentStats.usagePercentage, 100) / 100)),
                            height: 5
                        )
                }
            }
            .frame(height: 5)
        }
    }

    private var progressColor: Color {
        let percentage = viewModel.currentStats.usagePercentage
        if percentage < 50 { return .green }
        else if percentage < 75 { return .yellow }
        else if percentage < 90 { return .orange }
        else { return .red }
    }

    // MARK: - Charts

    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Usage History")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                historyTabs
            }
            .padding(.horizontal, 16)

            if historyData.isEmpty {
                Text("No usage data yet")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(.horizontal, 16)
            } else {
                Chart(historyData) { point in
                    BarMark(
                        x: .value("Period", point.periodStart, unit: xAxisUnit),
                        y: .value("Tokens", point.totalTokens)
                    )
                    .cornerRadius(4)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.9),
                                Color.cyan.opacity(0.7)
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .annotation(position: .top) {
                        Text(point.formattedTokens)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: historyData.map { $0.periodStart }) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(axisLabel(for: date))
                                    .font(.system(size: 9, weight: .medium))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            AxisGridLine().foregroundStyle(.primary.opacity(0.05))
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(.primary.opacity(0.05))
                    }
                }
                .frame(height: 160)
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
            }

            if !historyData.isEmpty {
                HStack {
                    Text("\(historyTotalTokens.formattedCompact) tokens")
                    Spacer()
                    Text(historyTotalCost.formattedAsCurrency)
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            }
        }
        .padding(.top, 10)
    }

    private var historyTabs: some View {
        HStack(spacing: 6) {
            ForEach(UsageHistoryRange.allCases, id: \.self) { range in
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        selectedHistoryRange = range
                    }
                } label: {
                    Text(range.displayName)
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(selectedHistoryRange == range ? Color.primary.opacity(0.14) : Color.primary.opacity(0.06))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.primary.opacity(selectedHistoryRange == range ? 0.14 : 0.06), lineWidth: 0.5)
                        )
                        .foregroundStyle(.primary.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var historyData: [UsageHistoryPoint] {
        switch selectedHistoryRange {
        case .daily:
            return viewModel.dailyHistory
        case .weekly:
            return viewModel.weeklyHistory
        case .monthly:
            return viewModel.monthlyHistory
        }
    }

    private var historyTotalTokens: Int {
        historyData.reduce(0) { $0 + $1.totalTokens }
    }

    private var historyTotalCost: Double {
        historyData.reduce(0) { $0 + $1.totalCost }
    }

    private func axisLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current

        if Calendar.current.isDateInToday(date) {
            return "Today"
        }

        switch selectedHistoryRange {
        case .daily:
            formatter.dateFormat = "M/d"
        case .weekly:
            formatter.dateFormat = "MMM d"
        case .monthly:
            formatter.dateFormat = "MMM"
        }

        return formatter.string(from: date)
    }

    private var xAxisUnit: Calendar.Component {
        switch selectedHistoryRange {
        case .daily:
            return .day
        case .weekly:
            return .weekOfYear
        case .monthly:
            return .month
        }
    }

    private func valueLabel(for value: Double) -> String {
        Int(value).formattedCompact
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 6) {
            GlassActionButton(title: "Refresh", icon: "arrow.clockwise", fontSize: viewModel.fontSize) {
                viewModel.refresh(force: true)
            }

            GlassActionButton(title: "Settings", icon: "gearshape", fontSize: viewModel.fontSize) {
                openSettings()
            }

            GlassActionButton(title: "Quit", icon: "power", fontSize: viewModel.fontSize) {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private func openSettings() {
        NotificationCenter.default.post(name: .openSettings, object: nil)
    }
}

// MARK: - Visual Effect View (NSVisualEffectView wrapper)

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Stat Row

struct StatRow: View {
    let icon: String
    let color: Color
    let title: String
    let value: String
    var fontSize: FontSizeOption = .medium

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: fontSize.iconContainerSize, height: fontSize.iconContainerSize)

                Image(systemName: icon)
                    .font(.system(size: fontSize.iconSize, weight: .semibold))
                    .foregroundStyle(color)
            }

            Text(title)
                .font(.system(size: fontSize.titleSize))
                .foregroundStyle(.primary.opacity(0.85))

            Spacer()

            Text(value)
                .font(.system(size: fontSize.valueSize, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Stat Row No Icon (for additional models)

struct StatRowNoIcon: View {
    let value: String
    var fontSize: FontSizeOption = .medium

    var body: some View {
        HStack(spacing: 10) {
            // Placeholder to keep alignment
            Color.clear
                .frame(width: fontSize.iconContainerSize, height: fontSize.iconContainerSize)

            Spacer()

            Text(value)
                .font(.system(size: fontSize.valueSize, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Glass Action Button

struct GlassActionButton: View {
    let title: String
    let icon: String
    var fontSize: FontSizeOption = .medium
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    private var iconSize: CGFloat {
        switch fontSize {
        case .small: return 8
        case .medium: return 9
        case .large: return 10
        }
    }

    private var textSize: CGFloat {
        switch fontSize {
        case .small: return 9
        case .medium: return 10
        case .large: return 11
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .semibold))
                Text(title)
                    .font(.system(size: textSize, weight: .medium))
            }
            .foregroundStyle(.primary.opacity(0.75))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.primary.opacity(isHovered ? 0.12 : 0.06))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
            }
            .scaleEffect(isPressed ? 0.95 : 1)
        }
        .buttonStyle(.plain)
        .onHover { hover in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hover
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeOut(duration: 0.1)) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: 0.1)) { isPressed = false }
                }
        )
    }
}

// MARK: - Usage History Range

private enum UsageHistoryRange: String, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"

    var displayName: String {
        rawValue
    }
}
