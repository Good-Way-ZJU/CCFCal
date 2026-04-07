import DDLCalCore
import Foundation
import Testing

@Test func filteringSupportsRankDomainKindAndQuery() throws {
    let store = CandidateStore(items: SampleData.items)
    let filter = DeadlineFilter(
        ranks: [.a],
        domains: ["CV"],
        kinds: [.conference],
        query: "cvpr"
    )

    let result = store.filtered(using: filter)
    #expect(result.count == 1)
    #expect(result.first?.shortName == "CVPR 2027")
}

@Test func subscriptionStoreTracksSelectedItems() throws {
    var subscriptions = SubscriptionStore()
    subscriptions.subscribe("cvpr-2027")
    #expect(subscriptions.contains("cvpr-2027"))
    subscriptions.unsubscribe("cvpr-2027")
    #expect(!subscriptions.contains("cvpr-2027"))
}

@Test func calendarSyncBuildsEventsForSubscribedItemsOnly() throws {
    let store = CandidateStore(items: SampleData.items)
    var subscriptions = SubscriptionStore()
    subscriptions.subscribe("cvpr-2027")
    let now = ISO8601DateFormatter().date(from: "2026-06-01T00:00:00Z")!

    let payloads = CalendarSyncEngine.payloads(from: store, subscriptions: subscriptions, now: now)
    #expect(payloads.count == 2)
    #expect(payloads[0].title.contains("[DDL]"))
    #expect(payloads[0].notes.contains("item_id:cvpr-2027"))
}

@Test func nextSummaryReturnsClosestFutureDeadline() throws {
    let store = CandidateStore(items: SampleData.items)
    var subscriptions = SubscriptionStore()
    subscriptions.subscribe("jos")
    subscriptions.subscribe("cvpr-2027")
    let now = ISO8601DateFormatter().date(from: "2026-05-01T00:00:00Z")!

    let summary = UpcomingDeadlineResolver.nextSummary(from: store, subscriptions: subscriptions, now: now)
    #expect(summary?.title == "JOS")
}

@Test func countdownFormatsDayHourMinuteOutput() throws {
    let formatter = ISO8601DateFormatter()
    let start = formatter.date(from: "2026-05-01T00:00:00Z")!
    let end = formatter.date(from: "2026-05-03T05:45:00Z")!

    let countdown = UpcomingDeadlineResolver.countdown(to: end, now: start, calendar: Calendar(identifier: .gregorian))
    #expect(countdown.displayText == "2 day 5 hours 45 min")
}

@Test func widgetSharedStorePersistsSummary() throws {
    let suiteName = "DDLCalTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    let store = WidgetSharedStore(userDefaults: defaults)
    let summary = UpcomingDeadlineSummary(
        title: "ICLR 2027",
        stage: "Full Paper",
        timestamp: ISO8601DateFormatter().date(from: "2026-10-01T07:59:00Z")!
    )

    try store.save(summary: summary)
    let loaded = try store.loadSummary()
    #expect(loaded == summary)
}

private enum SampleData {
    static func date(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)!
    }

    static let items: [CandidateItem] = [
        CandidateItem(
            id: "cvpr-2027",
            title: "Conference on Computer Vision and Pattern Recognition",
            shortName: "CVPR 2027",
            kind: .conference,
            ccfRank: .a,
            domains: ["CV", "AI"],
            deadlines: [
                Deadline(stage: "Abstract", timestamp: date("2026-11-08T07:59:00Z"), timezone: "AoE"),
                Deadline(stage: "Full Paper", timestamp: date("2026-11-15T07:59:00Z"), timezone: "AoE")
            ],
            url: URL(string: "https://cvpr.thecvf.com")!
        ),
        CandidateItem(
            id: "jos",
            title: "Journal of Software",
            shortName: "JOS",
            kind: .journal,
            ccfRank: .b,
            domains: ["SE"],
            deadlines: [
                Deadline(stage: "Monthly Submission Window", timestamp: date("2026-05-31T15:59:00Z"), timezone: "Asia/Shanghai")
            ],
            url: URL(string: "https://www.jos.org.cn")!
        ),
        CandidateItem(
            id: "wise-2027",
            title: "Web Information Systems Engineering",
            shortName: "WISE 2027",
            kind: .conference,
            ccfRank: .c,
            domains: ["WEB", "DB"],
            deadlines: [
                Deadline(stage: "Full Paper", timestamp: date("2026-08-16T07:59:00Z"), timezone: "AoE")
            ],
            url: URL(string: "https://wise2027.example.org")!
        )
    ]
}
