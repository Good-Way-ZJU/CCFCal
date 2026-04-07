import SwiftUI
import WidgetKit

@available(macOS 14.0, *)
struct DDLCountdownEntry: TimelineEntry {
    let date: Date
    let snapshot: DDLCountdownSnapshot
}

@available(macOS 14.0, *)
struct DDLCountdownProvider: TimelineProvider {
    func placeholder(in context: Context) -> DDLCountdownEntry {
        DDLCountdownEntry(date: Date(), snapshot: DDLWidgetDataLoader.loadPlaceholderSnapshot())
    }

    func getSnapshot(in context: Context, completion: @escaping (DDLCountdownEntry) -> Void) {
        completion(DDLCountdownEntry(date: Date(), snapshot: DDLWidgetDataLoader.loadLiveSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DDLCountdownEntry>) -> Void) {
        let entry = DDLCountdownEntry(date: Date(), snapshot: DDLWidgetDataLoader.loadLiveSnapshot())
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 1, to: Date()) ?? Date().addingTimeInterval(60)
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }
}

@available(macOS 14.0, *)
struct DDLCountdownWidgetEntryView: View {
    var entry: DDLCountdownProvider.Entry
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let items = entry.snapshot.items
        Group {
            if items.isEmpty {
                emptyState
            } else {
                switch family {
                case .systemSmall:
                    smallCard(items[0])
                case .systemMedium:
                    multiCard(Array(items.prefix(3)))
                default:
                    multiCard(Array(items.prefix(4)))
                }
            }
        }
        .padding(widgetPadding)
        .containerBackground(for: .widget) {
            ZStack {
                RoundedRectangle(cornerRadius: widgetCornerRadius, style: .continuous)
                    .fill(widgetBackground)
                ambientGlow
                RoundedRectangle(cornerRadius: widgetCornerRadius, style: .continuous)
                    .stroke(widgetBorder, lineWidth: 1)
            }
        }
    }

    private var widgetPadding: CGFloat {
        family == .systemSmall ? 14 : 16
    }

    private var widgetCornerRadius: CGFloat {
        family == .systemSmall ? 24 : 28
    }

    private var widgetBackground: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(colors: [
                Color(red: 0.10, green: 0.11, blue: 0.14),
                Color(red: 0.14, green: 0.15, blue: 0.18)
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        return LinearGradient(colors: [
            Color(red: 0.98, green: 0.97, blue: 0.95),
            Color(red: 0.94, green: 0.95, blue: 0.99)
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var widgetBorder: Color {
        colorScheme == .dark
        ? Color.white.opacity(0.08)
        : Color.black.opacity(0.06)
    }

    private var panelFill: Color {
        colorScheme == .dark
        ? Color.white.opacity(0.04)
        : Color.white.opacity(0.70)
    }

    private var panelStroke: Color {
        colorScheme == .dark
        ? Color.white.opacity(0.06)
        : Color.black.opacity(0.06)
    }

    private var ambientGlow: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(colorScheme == .dark ? 0.04 : 0.22))
                .frame(width: family == .systemSmall ? 120 : 170)
                .blur(radius: 30)
                .offset(x: family == .systemSmall ? -42 : -68, y: family == .systemSmall ? -58 : -82)
            Circle()
                .fill(Color(red: 0.89, green: 0.38, blue: 0.29).opacity(colorScheme == .dark ? 0.10 : 0.08))
                .frame(width: family == .systemSmall ? 80 : 110)
                .blur(radius: 22)
                .offset(x: family == .systemSmall ? 56 : 100, y: family == .systemSmall ? 72 : 112)
        }
    }

    private func panelBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(panelFill)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(panelStroke, lineWidth: 1)
            )
    }

    private func headerView(title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: family == .systemSmall ? 17 : 20, weight: .bold))
                    .foregroundStyle(Color(nsColor: .labelColor))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if family != .systemSmall {
                Text("\(entry.snapshot.items.count)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(panelFill.opacity(colorScheme == .dark ? 1 : 0.9), in: Capsule())
            }
        }
    }

    private func accentStripe(_ accent: Color) -> some View {
        RoundedRectangle(cornerRadius: 999, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [accent, accent.opacity(colorScheme == .dark ? 0.55 : 0.72)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 5)
    }

    private func countdownBlock(for item: DDLCountdownItem, accent: Color, alignTrailing: Bool) -> some View {
        VStack(alignment: alignTrailing ? .trailing : .leading, spacing: 3) {
            if let deadline = item.deadlineDate {
                Text(DDLCountdownFormatter.string(from: entry.date, to: deadline))
                    .font(.system(size: alignTrailing ? 14 : 28, weight: .bold, design: .rounded))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
                Text(item.display)
                    .font(.caption2)
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerView(title: "CCFCal", subtitle: "No tracked venues yet")
            VStack(alignment: .leading, spacing: 10) {
                Text("Subscribe to a few conferences or journals in the app.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(nsColor: .labelColor))
                Text("Your countdowns will appear here automatically.")
                    .font(.caption)
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(panelBackground(cornerRadius: 18))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func smallCard(_ item: DDLCountdownItem) -> some View {
        let accent = accentColor(for: item)
        return VStack(alignment: .leading, spacing: 12) {
            headerView(title: "Next Up", subtitle: item.kind.capitalized)
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    accentStripe(accent)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            rankPill(item.ccfRank, accent: accent)
                            Spacer(minLength: 8)
                        }
                        Text(item.title)
                            .font(.system(size: 22, weight: .bold))
                            .lineLimit(3)
                            .minimumScaleFactor(0.78)
                            .foregroundStyle(Color(nsColor: .labelColor))
                        if !item.metaLine.isEmpty {
                            Text(item.metaLine)
                                .font(.caption)
                                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                                .lineLimit(3)
                                .minimumScaleFactor(0.82)
                        }
                    }
                }
                Spacer(minLength: 0)
                countdownBlock(for: item, accent: accent, alignTrailing: false)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(panelBackground(cornerRadius: 20))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func multiCard(_ items: [DDLCountdownItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            headerView(title: "Tracked Venues", subtitle: "Synced with your subscriptions")
            ForEach(items) { item in
                let accent = accentColor(for: item)
                HStack(alignment: .top, spacing: 12) {
                    accentStripe(accent)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top, spacing: 8) {
                            Text(item.title)
                                .font(.system(size: 17, weight: .bold))
                                .lineLimit(2)
                                .minimumScaleFactor(0.78)
                                .foregroundStyle(Color(nsColor: .labelColor))
                            rankPill(item.ccfRank, accent: accent)
                        }
                        if !item.metaLine.isEmpty {
                            Text(item.metaLine)
                                .font(.caption)
                                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                                .lineLimit(2)
                                .minimumScaleFactor(0.80)
                        }
                    }
                    Spacer(minLength: 8)
                    countdownBlock(for: item, accent: accent, alignTrailing: true)
                        .frame(minWidth: family == .systemLarge ? 110 : 100, alignment: .trailing)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, family == .systemLarge ? 10 : 9)
                .background(panelBackground(cornerRadius: 18))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func rankPill(_ rank: String, accent: Color) -> some View {
        Text("CCF-\(rank)")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(accent.opacity(colorScheme == .dark ? 0.24 : 0.14), in: Capsule())
            .foregroundStyle(accent)
    }

    private func accentColor(for item: DDLCountdownItem) -> Color {
        let nsColor = item.accentNSColor.ddlReadableAccent
        return Color(nsColor: nsColor)
    }
}

@available(macOS 14.0, *)
struct DDLCountdownWidget: Widget {
    let kind: String = "DDLCountdownWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DDLCountdownProvider()) { entry in
            DDLCountdownWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("CCFCal Countdown")
        .description("Show one or more upcoming subscribed venue countdowns from CCFCal.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
