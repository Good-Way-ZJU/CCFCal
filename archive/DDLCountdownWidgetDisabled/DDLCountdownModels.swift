import Foundation
import AppKit
import SwiftUI

struct DDLCountdownItem: Decodable, Identifiable {
    let itemID: String
    let title: String
    let stage: String
    let timestamp: String
    let display: String
    let ccfRank: String
    let domains: [String]
    let kind: String
    let url: String
    let colorHex: String?

    var id: String { "\(itemID)-\(timestamp)" }

    var deadlineDate: Date? {
        ISO8601DateFormatter.widgetSnapshotFormatter.date(from: timestamp)
    }

    enum CodingKeys: String, CodingKey {
        case itemID = "item_id"
        case title
        case stage
        case timestamp
        case display
        case ccfRank = "ccf_rank"
        case domains
        case kind
        case url
        case colorHex = "color_hex"
    }

    var accentNSColor: NSColor {
        guard let colorHex, colorHex.isEmpty == false else {
            return NSColor(calibratedRed: 0.84, green: 0.19, blue: 0.17, alpha: 1.0)
        }
        return NSColor.ddlColor(fromHex: colorHex)
    }

    var accentColor: Color {
        Color(nsColor: accentNSColor)
    }

    var stageLabel: String {
        let normalized = stage.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.lowercased() == "deadline" {
            return ""
        }
        return normalized
    }

    var metaLine: String {
        var components: [String] = []
        if !stageLabel.isEmpty {
            components.append(stageLabel)
        }
        if !domains.isEmpty {
            let visibleDomains = Array(domains.prefix(2))
            var domainLine = visibleDomains.joined(separator: " / ")
            if domains.count > visibleDomains.count {
                domainLine += " +\(domains.count - visibleDomains.count)"
            }
            components.append(domainLine)
        }
        return components.joined(separator: " · ")
    }
}

struct DDLCountdownSnapshot: Decodable {
    let generatedAt: TimeInterval
    let items: [DDLCountdownItem]

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case items
    }
}

extension ISO8601DateFormatter {
    static let widgetSnapshotFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

enum DDLWidgetDataLoader {
    static let appGroupID = "group.com.guwei.ddlcal.shared"
    static let snapshotName = "DDLCountdownSnapshot.json"

    static func loadLiveSnapshot() -> DDLCountdownSnapshot {
        let decoder = JSONDecoder()
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let liveURL = containerURL.appendingPathComponent(snapshotName)
            if let data = try? Data(contentsOf: liveURL),
               let snapshot = try? decoder.decode(DDLCountdownSnapshot.self, from: data) {
                return snapshot
            }
        }

        return DDLCountdownSnapshot(generatedAt: Date().timeIntervalSince1970, items: [])
    }

    static func loadPlaceholderSnapshot() -> DDLCountdownSnapshot {
        let decoder = JSONDecoder()
        if let bundledURL = Bundle.main.url(forResource: "SampleCountdownSnapshot", withExtension: "json"),
           let data = try? Data(contentsOf: bundledURL),
           let snapshot = try? decoder.decode(DDLCountdownSnapshot.self, from: data) {
            return snapshot
        }

        return DDLCountdownSnapshot(generatedAt: Date().timeIntervalSince1970, items: [])
    }
}

enum DDLCountdownFormatter {
    static func string(from now: Date, to deadline: Date) -> String {
        let seconds = max(0, Int(deadline.timeIntervalSince(now)))
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60
        return "\(days)d \(hours)h \(minutes)m"
    }
}

extension NSColor {
    static func ddlColor(fromHex hex: String) -> NSColor {
        var normalized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if normalized.hasPrefix("#") {
            normalized.removeFirst()
        }
        if normalized.count != 6 {
            normalized = "D62F2B"
        }

        var rgbValue: UInt64 = 0
        Scanner(string: normalized).scanHexInt64(&rgbValue)
        return NSColor(
            srgbRed: CGFloat((rgbValue >> 16) & 0xFF) / 255.0,
            green: CGFloat((rgbValue >> 8) & 0xFF) / 255.0,
            blue: CGFloat(rgbValue & 0xFF) / 255.0,
            alpha: 1.0
        )
    }

    var ddlRelativeLuminance: CGFloat {
        guard let srgb = usingColorSpace(.sRGB) else { return 0 }
        func convert(_ component: CGFloat) -> CGFloat {
            component <= 0.03928 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
        }
        let red = convert(srgb.redComponent)
        let green = convert(srgb.greenComponent)
        let blue = convert(srgb.blueComponent)
        return 0.2126 * red + 0.7152 * green + 0.0722 * blue
    }

    var ddlReadableAccent: NSColor {
        guard ddlRelativeLuminance > 0.6 else { return self }
        return blended(withFraction: 0.35, of: .black) ?? self
    }
}
