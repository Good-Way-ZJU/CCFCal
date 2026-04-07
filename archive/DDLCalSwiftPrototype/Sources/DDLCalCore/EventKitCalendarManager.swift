import Foundation

#if canImport(EventKit)
import EventKit

public final class EventKitCalendarManager {
    private let eventStore: EKEventStore

    public init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
    }

    @MainActor
    public func requestAccess() async throws {
        let granted: Bool = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            eventStore.requestAccess(to: .event) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
        if !granted {
            throw CalendarAccessError.permissionDenied
        }
    }

    @MainActor
    public func sync(payloads: [CalendarEventPayload], now: Date = .now) throws {
        let calendar = try managedCalendar()
        let existingEvents = try managedEvents(in: calendar, now: now)
        let existingByManagedID = Dictionary(
            uniqueKeysWithValues: existingEvents.compactMap { event -> (String, EKEvent)? in
                guard let managedID = managedIdentifier(from: event.notes) else { return nil }
                return (managedID, event)
            }
        )

        let payloadIDs = Set(payloads.map(\.identifier))
        for (managedID, event) in existingByManagedID where !payloadIDs.contains(managedID) {
            try eventStore.remove(event, span: .thisEvent, commit: false)
        }

        for payload in payloads {
            let event = existingByManagedID[payload.identifier] ?? EKEvent(eventStore: eventStore)
            event.calendar = calendar
            event.title = payload.title
            event.startDate = payload.startDate
            event.endDate = payload.endDate
            event.timeZone = .current
            event.url = payload.url
            event.notes = payload.notes
            try eventStore.save(event, span: .thisEvent, commit: false)
        }

        if !payloads.isEmpty || !existingByManagedID.isEmpty {
            try eventStore.commit()
        }
    }

    @MainActor
    public func clearManagedCalendar(now: Date = .now) throws {
        let calendar = try managedCalendar()
        let events = try managedEvents(in: calendar, now: now)
        for event in events {
            try eventStore.remove(event, span: .thisEvent, commit: false)
        }
        if !events.isEmpty {
            try eventStore.commit()
        }
    }

    @MainActor
    private func managedCalendar() throws -> EKCalendar {
        if let existing = eventStore.calendars(for: .event).first(where: { $0.title == CalendarSyncEngine.calendarName }) {
            return existing
        }

        guard let source = eventStore.defaultCalendarForNewEvents?.source ?? eventStore.sources.first else {
            throw CalendarAccessError.noWritableSource
        }

        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = CalendarSyncEngine.calendarName
        calendar.cgColor = CGColor(red: 0.87, green: 0.19, blue: 0.19, alpha: 1.0)
        calendar.source = source
        try eventStore.saveCalendar(calendar, commit: true)
        return calendar
    }

    @MainActor
    private func managedEvents(in calendar: EKCalendar, now: Date) throws -> [EKEvent] {
        let end = Calendar.current.date(byAdding: .year, value: 5, to: now) ?? now.addingTimeInterval(86400 * 365 * 5)
        let predicate = eventStore.predicateForEvents(withStart: now.addingTimeInterval(-86400), end: end, calendars: [calendar])
        return eventStore.events(matching: predicate).filter { managedIdentifier(from: $0.notes) != nil }
    }

    private func managedIdentifier(from notes: String?) -> String? {
        notes?
            .split(separator: "\n")
            .first(where: { $0.hasPrefix("ddlcal_id:") })
            .map { String($0.dropFirst("ddlcal_id:".count)) }
    }
}

public enum CalendarAccessError: Error {
    case permissionDenied
    case noWritableSource
}
#endif
