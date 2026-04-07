import Foundation

public struct WidgetSharedStore {
    private let userDefaults: UserDefaults
    private let key: String

    public init(userDefaults: UserDefaults, key: String = "nextDeadlineSummary") {
        self.userDefaults = userDefaults
        self.key = key
    }

    public func save(summary: UpcomingDeadlineSummary?) throws {
        if let summary {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(summary)
            userDefaults.set(data, forKey: key)
        } else {
            userDefaults.removeObject(forKey: key)
        }
    }

    public func loadSummary() throws -> UpcomingDeadlineSummary? {
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(UpcomingDeadlineSummary.self, from: data)
    }
}
