import Foundation

struct CalendarEvent: Identifiable, Hashable {
    enum CalendarType: String, CaseIterable {
        case work
        case personal
        case focus

        var displayName: String {
            switch self {
            case .work: return "Work"
            case .personal: return "Personal"
            case .focus: return "Deep Work"
            }
        }
    }

    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let calendarType: CalendarType
    let location: String?
    let notes: String?

    init(
        id: String = UUID().uuidString,
        title: String,
        startDate: Date,
        endDate: Date,
        calendarType: CalendarType,
        location: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.calendarType = calendarType
        self.location = location
        self.notes = notes
    }

    var isAllDay: Bool {
        Calendar.current.isDate(startDate, equalTo: endDate, toGranularity: .day) &&
            Calendar.current.component(.hour, from: startDate) == 0 &&
            Calendar.current.component(.hour, from: endDate) == 23
    }

    var timeRangeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"

        if isAllDay {
            return "All day"
        }

        return "\(formatter.string(from: startDate)) – \(formatter.string(from: endDate))"
    }

    var durationDescription: String {
        let duration = endDate.timeIntervalSince(startDate)
        let minutes = Int(duration / 60)
        if minutes >= 60 {
            let hours = minutes / 60
            let remaining = minutes % 60
            if remaining == 0 {
                return "\(hours)h"
            }
            return "\(hours)h \(remaining)m"
        }
        return "\(minutes)m"
    }
}
