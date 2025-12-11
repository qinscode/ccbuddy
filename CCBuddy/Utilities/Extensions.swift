import Foundation
import SwiftUI
import AppKit

// MARK: - Date Extensions

extension Date {
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }

    var isThisWeek: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .weekOfYear)
    }

    var isThisMonth: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .month)
    }

    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    func hoursAgo(_ hours: Double) -> Date {
        addingTimeInterval(-hours * 60 * 60)
    }
}

// MARK: - Number Formatting

extension Int {
    var formattedWithSeparator: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }

    var formattedCompact: String {
        if self >= 1_000_000 {
            return String(format: "%.1fM", Double(self) / 1_000_000)
        } else if self >= 1_000 {
            return String(format: "%.1fK", Double(self) / 1_000)
        } else {
            return "\(self)"
        }
    }
}

extension Double {
    var formattedAsCurrency: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "$"
        formatter.maximumFractionDigits = 4
        return formatter.string(from: NSNumber(value: self)) ?? "$\(self)"
    }

    var formattedAsPercentage: String {
        String(format: "%.1f%%", self)
    }
}

// MARK: - TimeInterval Extensions

extension TimeInterval {
    var formattedAsHoursMinutes: String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60

        if hours > 0 {
            return String(format: "%d:%02d", hours, minutes)
        } else {
            let seconds = Int(self) % 60
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    var formattedAsShortDuration: String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "<1m"
        }
    }
}

// MARK: - Color Extensions

extension Color {
    static var progressGreen: Color {
        Color(red: 0.2, green: 0.8, blue: 0.4)
    }

    static var progressYellow: Color {
        Color(red: 0.95, green: 0.8, blue: 0.2)
    }

    static var progressOrange: Color {
        Color(red: 0.95, green: 0.6, blue: 0.2)
    }

    static var progressRed: Color {
        Color(red: 0.9, green: 0.3, blue: 0.3)
    }

    static func progressColor(for percentage: Double) -> Color {
        if percentage < 50 {
            return .progressGreen
        } else if percentage < 75 {
            return .progressYellow
        } else if percentage < 90 {
            return .progressOrange
        } else {
            return .progressRed
        }
    }
}

// MARK: - View Extensions

extension View {
    func cardStyle() -> some View {
        self
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
    }
}

// MARK: - Image Helpers

extension Image {
    static func loadLogo(named name: String) -> Image? {
        let bundles: [Bundle] = [Bundle.module, Bundle.main]
        for bundle in bundles {
            if let url = bundle.url(forResource: name, withExtension: "png"),
               let nsImage = NSImage(contentsOf: url) {
                return Image(nsImage: nsImage)
            }
        }
        return nil
    }
}
