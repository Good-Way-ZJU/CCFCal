import Foundation

public struct SubscriptionStore: Codable, Equatable, Sendable {
    public private(set) var subscribedItemIds: Set<String>

    public init(subscribedItemIds: Set<String> = []) {
        self.subscribedItemIds = subscribedItemIds
    }

    public mutating func subscribe(_ itemID: String) {
        subscribedItemIds.insert(itemID)
    }

    public mutating func unsubscribe(_ itemID: String) {
        subscribedItemIds.remove(itemID)
    }

    public func contains(_ itemID: String) -> Bool {
        subscribedItemIds.contains(itemID)
    }

    public func subscribedItems(in store: CandidateStore) -> [CandidateItem] {
        store.items.filter { subscribedItemIds.contains($0.id) }
    }
}
