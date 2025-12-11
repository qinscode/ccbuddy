import SwiftUI
import AppKit

struct SettingsView: View {
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
        ZStack {
            // Native macOS glass background
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            Color.primary.opacity(0.03) // subtle tint to keep contrast

            // Layer 2: Content
            VStack(spacing: 0) {
                // Floating Glass Tab Bar
                glassTabBar
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                
                // Content Area
                ZStack(alignment: .top) {
                    switch selectedTab {
                    case .general:
                        generalSettings
                            .transition(.opacity.combined(with: .move(edge: .bottom).combined(with: .scale(scale: 0.98))))
                    case .appearance:
                        appearanceSettings
                            .transition(.opacity.combined(with: .move(edge: .bottom).combined(with: .scale(scale: 0.98))))
                    case .notifications:
                        notificationSettings
                            .transition(.opacity.combined(with: .move(edge: .bottom).combined(with: .scale(scale: 0.98))))
                    case .about:
                        aboutView
                            .transition(.opacity.combined(with: .move(edge: .bottom).combined(with: .scale(scale: 0.98))))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(width: 560, height: 480)
    }
    
    // MARK: - Glass Tab Bar
    
    private var glassTabBar: some View {
        HStack(spacing: 0) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 12, weight: .medium))
                            .symbolVariant(selectedTab == tab ? .fill : .none)
                        
                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: selectedTab == tab ? .semibold : .medium))
                            .fixedSize()
                    }
                    .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .contentShape(Rectangle())
                    .background {
                        if selectedTab == tab {
                            Capsule()
                                .fill(.thinMaterial)
                                .matchedGeometryEffect(id: "TabBackground", in: animation)
                                .shadow(color: .black.opacity(0.08), radius: 5, x: 0, y: 0)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }

    // MARK: - General Settings

    private var generalSettings: some View {
        VStack(spacing: 12) {
            // Usage Mode Card
            GlassCard(title: "Usage Mode") {
                HStack(spacing: 10) {
                    usageModeCard(for: .proMax, icon: "crown.fill", title: "Pro / Max", desc: "5h window, weekly limits")
                    usageModeCard(for: .api, icon: "creditcard.fill", title: "API Mode", desc: "Pay per token, no limits")
                }
            }
            
            // Behavior Options Card
            GlassCard(title: "Behavior") {
                VStack(spacing: 12) {
                    GlassToggle(title: "Launch at Login", icon: "rocket.fill", isOn: $launchAtLogin)
                    
                    Divider().background(Color.primary.opacity(0.08))
                    
                    HStack {
                        Label {
                            Text("Refresh Interval")
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Picker("", selection: $viewModel.refreshInterval) {
                            Text("1s").tag(1)
                            Text("5s").tag(5)
                            Text("10s").tag(10)
                            Text("30s").tag(30)
                            Text("1m").tag(60)
                            Text("5m").tag(300)
                            Text("Manual").tag(0)
                        }
                        .labelsHidden()
                        .frame(width: 100)
                    }
                    
                    Divider().background(Color.primary.opacity(0.08))
                    
                    HStack {
                        Label {
                            Text("Menu Bar Display")
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "menubar.rectangle")
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Picker("", selection: $viewModel.showInMenuBar) {
                            ForEach(MenuBarDisplay.allCases, id: \.self) { option in
                                Text(option.displayName).tag(option)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 120)
                    }
                    
                    Divider().background(Color.primary.opacity(0.08))
                    
                    HStack {
                        Label {
                            Text("Data Location")
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "externaldrive.fill")
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Button {
                            let path = NSString(string: "~/.claude/projects/").expandingTildeInPath
                            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                        } label: {
                            HStack(spacing: 6) {
                                Text("Change...")
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                                Image(systemName: "folder")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func usageModeCard(for mode: UsageMode, icon: String, title: String, desc: String) -> some View {
        let isSelected = viewModel.usageMode == mode
        
        return Button {
            withAnimation {
                viewModel.usageMode = mode
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: icon)
                        .font(.headline)
                        .foregroundStyle(isSelected ? .white : .primary.opacity(0.8))
                    
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(isSelected ? .white : .primary)
                }
                
                Text(desc)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                
                Spacer(minLength: 0)
                
                HStack {
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .shadow(color: .white.opacity(0.5), radius: 5)
                    } else {
                        Image(systemName: "circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.blue.opacity(0.7) : Color.primary.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? Color.white.opacity(0.9) : Color.primary.opacity(0.08), lineWidth: isSelected ? 1.5 : 0.5)
                    )
                    .shadow(color: isSelected ? .blue.opacity(0.35) : .clear, radius: 10)
            }
        }
        .buttonStyle(.plain)
        .opacity(isSelected ? 1.0 : 0.8) // Dim unselected card slightly
    }

    // MARK: - Appearance Settings

    private var appearanceSettings: some View {
        VStack(spacing: 12) {
            GlassCard(title: "Glass Effect") {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Transparency")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("\(Int(viewModel.glassOpacity * 100))%")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }

                        Slider(value: $viewModel.glassOpacity, in: 0...1, step: 0.05)
                            .tint(.primary)
                    }

                    Divider().background(Color.primary.opacity(0.08))

                    HStack {
                        Text("Material Style")
                            .foregroundStyle(.primary)
                        Spacer()
                        Picker("", selection: $viewModel.materialStyle) {
                            ForEach(GlassMaterialStyle.allCases, id: \.self) { style in
                                Text(style.displayName).tag(style)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 120)
                    }
                }
            }
            
            GlassCard(title: "Preview") {
                previewBox
            }
        }
    }
    
    private var previewBox: some View {
        ZStack {
            LinearGradient(
                colors: [.blue, .purple, .pink],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack {
                Text("Glass Preview")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("Transparency: \(Int(viewModel.glassOpacity * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(12)
        }
    }

    // MARK: - Notification Settings

    private var notificationSettings: some View {
        GlassCard(title: "Notifications") {
            VStack(spacing: 12) {
                GlassToggle(title: "Enable Notifications", icon: "bell.badge.fill", isOn: $showNotifications)
                
                if showNotifications {
                    Divider().background(Color.primary.opacity(0.08))
                    
                    HStack {
                        Text("Alert Threshold")
                            .foregroundStyle(.primary)
                        Spacer()
                        Picker("", selection: $notificationThreshold) {
                            Text("50%").tag(50)
                            Text("75%").tag(75)
                            Text("90%").tag(90)
                        }
                        .labelsHidden()
                        .frame(width: 80)
                    }
                    
                    Text("Get notified when usage exceeds this threshold")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - About View

    private var aboutView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [.blue.opacity(0.9), .purple.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 90, height: 90)
                    .blur(radius: 14)
                    .opacity(0.65)

                if let logo = Image.loadLogo(named: "logo-128") {
                    logo
                        .resizable()
                        .renderingMode(.original)
                        .scaledToFit()
                        .frame(width: 78, height: 78)
                } else {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.white)
                }
            }

            VStack(spacing: 6) {
                Text("CCBuddy")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                Text("Version 1.0.0")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
            }

            Text("Monitor your Claude Code usage in real-time with a beautiful native macOS app.")
                .font(.callout)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .padding(.vertical, 10)

            Link("View on GitHub", destination: URL(string: "https://github.com")!)
                .font(.subheadline)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.white.opacity(0.15))
                .clipShape(Capsule())

            Spacer()
        }
        .padding()
    }
}

// MARK: - Components

struct GlassCard<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: title.isEmpty ? 0 : 12) {
            if !title.isEmpty {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary) // High contrast title
            }
            
            content
        }
        .padding(16)
        .background(.regularMaterial) // Slightly thicker material for better contrast
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
    }
}

struct GlassToggle: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Label {
                Text(title)
                    .foregroundStyle(.primary)
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(.blue)
        }
        .padding(.vertical, 2)
    }
}

struct LiquidBackgroundView: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.85) // Darker base for better contrast
            
            // Blob 1
            Circle()
                .fill(Color.blue.opacity(0.3)) // Slightly reduced opacity
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: animate ? -100 : 100, y: animate ? -50 : 50)
                .animation(.easeInOut(duration: 10).repeatForever(autoreverses: true), value: animate)
            
            // Blob 2
            Circle()
                .fill(Color.purple.opacity(0.3))
                .frame(width: 350, height: 350)
                .blur(radius: 60)
                .offset(x: animate ? 100 : -100, y: animate ? 50 : -50)
                .animation(.easeInOut(duration: 12).repeatForever(autoreverses: true), value: animate)
            
            // Blob 3
            Circle()
                .fill(Color.cyan.opacity(0.2))
                .frame(width: 250, height: 250)
                .blur(radius: 50)
                .offset(x: animate ? -50 : 50, y: animate ? 100 : -100)
                .animation(.easeInOut(duration: 8).repeatForever(autoreverses: true), value: animate)
        }
        .onAppear {
            animate = true
        }
    }
}
