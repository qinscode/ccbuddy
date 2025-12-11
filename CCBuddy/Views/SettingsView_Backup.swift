import SwiftUI
import AppKit

struct SettingsView_Backup: View {
    @ObservedObject var viewModel: UsageViewModel
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showNotifications") private var showNotifications = true
    @AppStorage("notificationThreshold") private var notificationThreshold = 75
    
    @State private var selectedTab: SettingsTab = .general
    @Namespace private var animation

    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case appearance = "Appearance"
        case notifications = "Notifications"
        case about = "About"
        
        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .appearance: return "paintbrush"
            case .notifications: return "bell"
            case .about: return "info.circle"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom Tab Bar
            HStack(spacing: 0) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 14))
                                .symbolVariant(selectedTab == tab ? .fill : .none)
                            
                            Text(tab.rawValue)
                                .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .medium))
                        }
                        .foregroundColor(selectedTab == tab ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                        .background {
                            if selectedTab == tab {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(nsColor: .controlBackgroundColor))
                                    .matchedGeometryEffect(id: "TabBackground", in: animation)
                                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            // Content
            // Removed ScrollView here to prevent conflict with Form's internal scrolling
            Group {
                switch selectedTab {
                case .general:
                    generalSettings
                case .appearance:
                    appearanceSettings
                case .notifications:
                    notificationSettings
                case .about:
                    aboutView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 520, height: 480)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - General Settings

    private var generalSettings: some View {
        Form {
            usageModeSection

            Section("General") {
                Toggle(isOn: $launchAtLogin) {
                    Label("Launch at Login", systemImage: "rocket")
                }

                Picker(selection: $viewModel.refreshInterval) {
                    Text("1 second").tag(1)
                    Text("5 seconds").tag(5)
                    Text("10 seconds").tag(10)
                    Text("30 seconds").tag(30)
                    Text("1 minute").tag(60)
                    Text("5 minutes").tag(300)
                    Text("Manual only").tag(0)
                } label: {
                    Label("Refresh Interval", systemImage: "arrow.clockwise")
                }

                Picker(selection: $viewModel.showInMenuBar) {
                    ForEach(MenuBarDisplay.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                } label: {
                    Label("Menu Bar Display", systemImage: "menubar.rectangle")
                }

                LabeledContent {
                    HStack {
                        Text("~/.claude/projects/")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .truncationMode(.middle)
                        
                        Spacer()
                        
                        Button {
                            let path = NSString(string: "~/.claude/projects/").expandingTildeInPath
                            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                        } label: {
                            Image(systemName: "folder")
                        }
                        .buttonStyle(.borderless)
                        .help("Show in Finder")
                    }
                } label: {
                    Label("Data Location", systemImage: "externaldrive")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var usageModeSection: some View {
        Section("Usage Mode") {
            HStack(spacing: 12) {
                usageModeCard(for: .proMax, icon: "crown.fill")
                usageModeCard(for: .api, icon: "creditcard.fill")
            }
            .padding(.vertical, 4)
        }
    }

    private func usageModeCard(for mode: UsageMode, icon: String) -> some View {
        let isSelected = viewModel.usageMode == mode
        
        return Button {
            withAnimation {
                viewModel.usageMode = mode
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.headline)
                        .foregroundStyle(isSelected ? .blue : .secondary)
                    
                    Text(mode.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                Text(mode.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                
                Spacer(minLength: 0)
                
                HStack {
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                    } else {
                        Image(systemName: "circle")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Appearance Settings

    private var appearanceSettings: some View {
        Form {
            Section("Glass Effect") {
                VStack(alignment: .leading, spacing: 12) {
                    // Transparency Slider
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Transparency")
                            Spacer()
                            Text("\(Int(viewModel.glassOpacity * 100))%")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }

                        Slider(value: $viewModel.glassOpacity, in: 0...1, step: 0.05)
                            .tint(.blue)

                        HStack {
                            Text("Solid")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("Transparent")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Divider()

                    // Material Style Picker
                    Picker("Material Style", selection: $viewModel.materialStyle) {
                        ForEach(GlassMaterialStyle.allCases, id: \.self) { style in
                            Text(style.displayName).tag(style)
                        }
                    }

                    Text("Controls the blur intensity of the glass effect")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Font Size") {
                Picker("Size", selection: $viewModel.fontSize) {
                    ForEach(FontSizeOption.allCases, id: \.self) { size in
                        Text(size.displayName).tag(size)
                    }
                }
                .pickerStyle(.segmented)

                Text("Adjust the font size in the popover")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Preview") {
                previewBox
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Preview Box

    private var previewBox: some View {
        ZStack {
            // Sample background to show transparency
            LinearGradient(
                colors: [.blue, .purple, .pink],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Glass preview
            VStack {
                Text("Glass Preview")
                    .font(.headline)
                Text("Transparency: \(Int(viewModel.glassOpacity * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background {
                glassPreviewBackground
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(16)
        }
    }

    @ViewBuilder
    private var glassPreviewBackground: some View {
        ZStack {
            switch viewModel.materialStyle {
            case .ultraThin:
                Rectangle().fill(.ultraThinMaterial)
            case .thin:
                Rectangle().fill(.thinMaterial)
            case .regular:
                Rectangle().fill(.regularMaterial)
            case .thick:
                Rectangle().fill(.thickMaterial)
            case .ultraThick:
                Rectangle().fill(.ultraThickMaterial)
            }

            Color(NSColor.windowBackgroundColor)
                .opacity(1.0 - viewModel.glassOpacity)
        }
    }

    // MARK: - Notification Settings

    private var notificationSettings: some View {
        Form {
            Section {
                Toggle("Enable Notifications", isOn: $showNotifications)

                if showNotifications {
                    Picker("Alert Threshold", selection: $notificationThreshold) {
                        Text("50%").tag(50)
                        Text("75%").tag(75)
                        Text("90%").tag(90)
                    }

                    Text("Get notified when usage exceeds this threshold")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - About View

    private var aboutView: some View {
        VStack(spacing: 16) {
            Spacer()

            // App Icon
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue.opacity(1.0 - Double(index) * 0.3))
                        .frame(width: 12, height: CGFloat(40 - index * 10))
                }
            }

            Text("CCBuddy")
                .font(.title)
                .fontWeight(.bold)

            Text("Claude Code Usage Monitor")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Version 1.0.0")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()
                .frame(width: 200)

            Text("Monitor your Claude Code usage in real-time with a beautiful native macOS app.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Link("View on GitHub", destination: URL(string: "https://github.com")!)
                .font(.caption)

            Spacer()
        }
        .padding()
    }
}

#Preview {
    SettingsView(viewModel: UsageViewModel())
}
