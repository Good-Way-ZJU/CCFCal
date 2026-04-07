import Foundation

public enum CCFRank: String, Codable, CaseIterable, Sendable {
    case a = "A"
    case b = "B"
    case c = "C"
}

public enum PublicationKind: String, Codable, CaseIterable, Sendable {
    case conference
    case journal
}

public struct Deadline: Codable, Equatable, Hashable, Sendable {
    public let stage: String
    public let timestamp: Date
    public let timezone: String

    public init(stage: String, timestamp: Date, timezone: String) {
        self.stage = stage
        self.timestamp = timestamp
        self.timezone = timezone
    }
}

public struct CandidateItem: Codable, Equatable, Hashable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let shortName: String
    public let kind: PublicationKind
    public let ccfRank: CCFRank
    public let domains: [String]
    public let deadlines: [Deadline]
    public let url: URL

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case shortName = "short_name"
        case kind
        case ccfRank = "ccf_rank"
        case domains
        case deadlines
        case url
    }

    public init(id: String, title: String, shortName: String, kind: PublicationKind, ccfRank: CCFRank, domains: [String], deadlines: [Deadline], url: URL) {
        self.id = id
        self.title = title
        self.shortName = shortName
        self.kind = kind
        self.ccfRank = ccfRank
        self.domains = domains
        self.deadlines = deadlines.sorted { $0.timestamp < $1.timestamp }
        self.url = url
    }
}

public struct DeadlineFilter: Equatable, Sendable {
    public var ranks: Set<CCFRank>
    public var domains: Set<String>
    public var kinds: Set<PublicationKind>
    public var query: String

    public init(
        ranks: Set<CCFRank> = Set(CCFRank.allCases),
        domains: Set<String> = [],
        kinds: Set<PublicationKind> = Set(PublicationKind.allCases),
        query: String = ""
    ) {
        self.ranks = ranks
        self.domains = Set(domains.map { $0.uppercased() })
        self.kinds = kinds
        self.query = query
    }
}

public struct CalendarEventPayload: Equatable, Sendable {
    public let identifier: String
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let notes: String
    public let url: URL

    public init(identifier: String, title: String, startDate: Date, endDate: Date, notes: String, url: URL) {
        self.identifier = identifier
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.url = url
    }
}

public struct UpcomingDeadlineSummary: Codable, Equatable, Sendable {
    public let title: String
    public let stage: String
    public let timestamp: Date

    public init(title: String, stage: String, timestamp: Date) {
        self.title = title
        self.stage = stage
        self.timestamp = timestamp
    }
}

public struct CountdownComponents: Equatable, Sendable {
    public let days: Int
    public let hours: Int
    public let minutes: Int

    public init(days: Int, hours: Int, minutes: Int) {
        self.days = days
        self.hours = hours
        self.minutes = minutes
    }

    public var displayText: String {
        "\(days) day \(hours) hours \(minutes) min"
    }
}
