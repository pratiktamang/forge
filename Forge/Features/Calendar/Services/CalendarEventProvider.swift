import Foundation

protocol CalendarEventProviding {
    func events(for interval: DateInterval) -> [CalendarEvent]
    func events(on date: Date) -> [CalendarEvent]
}

struct SampleCalendarEventProvider: CalendarEventProviding {
    func events(for interval: DateInterval) -> [CalendarEvent] {
        generateEvents(basedOn: interval.start).filter { interval.contains($0.startDate) }
    }

    func events(on date: Date) -> [CalendarEvent] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        return events(for: DateInterval(start: start, end: end))
    }

    private func generateEvents(basedOn referenceDate: Date) -> [CalendarEvent] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)

        func makeEvent(
            dayOffset: Int,
            hour: Int,
            minute: Int,
            durationMinutes: Int,
            title: String,
            calendarType: CalendarEvent.CalendarType,
            location: String? = nil,
            notes: String? = nil
        ) -> CalendarEvent {
            guard let startBase = calendar.date(byAdding: .day, value: dayOffset, to: today),
                  let startDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: startBase),
                  let endDate = calendar.date(byAdding: .minute, value: durationMinutes, to: startDate)
            else {
                return CalendarEvent(
                    title: title,
                    startDate: today,
                    endDate: today,
                    calendarType: calendarType
                )
            }

            return CalendarEvent(
                title: title,
                startDate: startDate,
                endDate: endDate,
                calendarType: calendarType,
                location: location,
                notes: notes
            )
        }

        return [
            makeEvent(dayOffset: 0, hour: 9, minute: 30, durationMinutes: 45, title: "Daily Team Sync", calendarType: .work, location: "Zoom"),
            makeEvent(dayOffset: 0, hour: 13, minute: 0, durationMinutes: 60, title: "Product Review", calendarType: .work, location: "War Room"),
            makeEvent(dayOffset: 1, hour: 11, minute: 0, durationMinutes: 30, title: "1:1 with James", calendarType: .work, location: "Cafe downstairs"),
            makeEvent(dayOffset: 1, hour: 17, minute: 30, durationMinutes: 90, title: "Twelfth Night Rehearsal", calendarType: .personal, location: "Downtown Theater"),
            makeEvent(dayOffset: 2, hour: 10, minute: 0, durationMinutes: 120, title: "Deep Work Block", calendarType: .focus, notes: "Ship explore concept draft"),
            makeEvent(dayOffset: 3, hour: 8, minute: 0, durationMinutes: 60, title: "Studio Yoga", calendarType: .personal, location: "Flow Studio"),
            makeEvent(dayOffset: 4, hour: 15, minute: 0, durationMinutes: 45, title: "Client Handoff", calendarType: .work, location: "Meet"),
            makeEvent(dayOffset: 6, hour: 12, minute: 0, durationMinutes: 30, title: "Daily Team Sync", calendarType: .work),
            makeEvent(dayOffset: 7, hour: 19, minute: 0, durationMinutes: 120, title: "Birthday Dinner", calendarType: .personal, location: "Kin Khao"),
            makeEvent(dayOffset: 10, hour: 10, minute: 30, durationMinutes: 60, title: "Roadmap Review", calendarType: .work),
            makeEvent(dayOffset: 12, hour: 9, minute: 0, durationMinutes: 30, title: "Coffee with Amir", calendarType: .personal, location: "Four Barrel")
        ]
    }
}
