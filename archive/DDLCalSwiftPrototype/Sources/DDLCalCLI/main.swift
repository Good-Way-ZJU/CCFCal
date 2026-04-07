import DDLCalCore
import Foundation

let formatter = ISO8601DateFormatter()
formatter.formatOptions = [.withInternetDateTime]

let demoItems = [
    CandidateItem(
        id: "iclr-2027-demo",
        title: "International Conference on Learning Representations",
        shortName: "ICLR 2027",
        kind: .conference,
        ccfRank: .a,
        domains: ["AI", "ML"],
        deadlines: [
            Deadline(stage: "Full Paper", timestamp: formatter.date(from: "2026-10-01T07:59:00Z")!, timezone: "AoE")
        ],
        url: URL(string: "https://iclr.cc")!
    ),
    CandidateItem(
        id: "jos-demo",
        title: "Journal of Software",
        shortName: "JOS",
        kind: .journal,
        ccfRank: .b,
        domains: ["SE"],
        deadlines: [
            Deadline(stage: "Monthly Submission Window", timestamp: formatter.date(from: "2026-05-31T15:59:00Z")!, timezone: "Asia/Shanghai")
        ],
        url: URL(string: "https://www.jos.org.cn")!
    )
]

let store = CandidateStore(items: demoItems)
let filter = DeadlineFilter(ranks: [.a, .b], domains: ["AI", "SE"], kinds: [.conference, .journal], query: "")
let filtered = store.filtered(using: filter)
var subscriptions = SubscriptionStore()
filtered.map(\.id).forEach { subscriptions.subscribe($0) }

print("Filtered candidates: \(filtered.map(\.shortName).joined(separator: ", "))")
if let summary = UpcomingDeadlineResolver.nextSummary(from: store, subscriptions: subscriptions) {
    let countdown = UpcomingDeadlineResolver.countdown(to: summary.timestamp, now: Date(timeIntervalSince1970: 1_775_000_000))
    print("Next deadline: \(summary.title) \(summary.stage) -> \(countdown.displayText)")
}
