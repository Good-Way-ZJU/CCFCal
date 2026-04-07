import Foundation

public enum CalendarSyncEngine {
    public static let calendarName = "DDLCal Subscriptions"

    public static func payloads(
        from store: CandidateStore,
        subscriptions: SubscriptionStore,
        now: Date = .now
    ) -> [CalendarEventPayload] {
        subscriptions.subscribedItems(in: store)
            .flatMap { item in
                item.deadlines
                    .filter { $0.timestamp >= now }
                    .map { deadline in
                        let domainLabel = item.domains.first ?? "GEN"
                        let title = "[DDL][CCF-\(item.ccfRank.rawValue)][\(domainLabel)] \(item.shortName) \(deadline.stage)"
                        let notes = [
                            "ddlcal_id:\(item.id)|\(deadline.stage)",
                            "item_id:\(item.id)",
                            "ccf_rank:\(item.ccfRank.rawValue)",
                            "domains:\(item.domains.joined(separator: ","))",
                            "stage:\(deadline.stage)",
                            "kind:\(item.kind.rawValue)",
                            "url:\(item.url.absoluteString)",
                            "timezone:\(deadline.timezone)",
                        ].joined(separator: "\n")
                        return CalendarEventPayload(
                            identifier: "\(item.id)|\(deadline.stage)",
                            title: title,
                            startDate: deadline.timestamp,
                            endDate: deadline.timestamp,
                            notes: notes,
                            url: item.url
                        )
                    }
            }
            .sorted { $0.startDate < $1.startDate }
    }
}
