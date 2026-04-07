import Foundation

public struct CandidateStore: Sendable {
    public private(set) var items: [CandidateItem]

    public init(items: [CandidateItem]) {
        self.items = items.sorted { $0.shortName.localizedCaseInsensitiveCompare($1.shortName) == .orderedAscending }
    }

    public func filtered(using filter: DeadlineFilter) -> [CandidateItem] {
        items.filter { item in
            guard filter.ranks.contains(item.ccfRank) else { return false }
            guard filter.kinds.contains(item.kind) else { return false }
            if !filter.domains.isEmpty {
                let itemDomains = Set(item.domains.map { $0.uppercased() })
                guard !itemDomains.isDisjoint(with: filter.domains) else { return false }
            }
            if filter.query.isEmpty { return true }
            let haystack = "\(item.title) \(item.shortName)".folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            let needle = filter.query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            return haystack.contains(needle)
        }
    }

    public func item(id: String) -> CandidateItem? {
        items.first { $0.id == id }
    }

    public var allDomains: [String] {
        Array(Set(items.flatMap(\.domains))).sorted()
    }
}
