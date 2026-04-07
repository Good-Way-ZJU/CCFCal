import Foundation

public enum UpcomingDeadlineResolver {
    public static func nextSummary(
        from store: CandidateStore,
        subscriptions: SubscriptionStore,
        now: Date = .now
    ) -> UpcomingDeadlineSummary? {
        subscriptions.subscribedItems(in: store)
            .flatMap { item in
                item.deadlines
                    .filter { $0.timestamp >= now }
                    .map { deadline in
                        UpcomingDeadlineSummary(
                            title: item.shortName,
                            stage: deadline.stage,
                            timestamp: deadline.timestamp
                        )
                    }
            }
            .sorted { $0.timestamp < $1.timestamp }
            .first
    }

    public static func countdown(to date: Date, now: Date = .now, calendar: Calendar = .current) -> CountdownComponents {
        let clampedNow = min(now, date)
        let components = calendar.dateComponents([.day, .hour, .minute], from: clampedNow, to: date)
        return CountdownComponents(
            days: max(components.day ?? 0, 0),
            hours: max(components.hour ?? 0, 0),
            minutes: max(components.minute ?? 0, 0)
        )
    }
}
