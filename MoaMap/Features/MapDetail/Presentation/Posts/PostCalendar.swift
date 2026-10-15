import Foundation

/// 달력의 한 날. `month` 는 1~12 다.
nonisolated struct CalendarDay: Hashable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    var calendarMonth: CalendarMonth { CalendarMonth(year: year, month: month) }

    /// 날짜 경계는 `timeZone` 을 따른다.
    static func of(_ date: Date, timeZone: TimeZone) -> CalendarDay {
        let parts = CalendarMonth.gregorian(timeZone).dateComponents([.year, .month, .day], from: date)
        return CalendarDay(year: parts.year ?? 0, month: parts.month ?? 1, day: parts.day ?? 1)
    }
}

/// 달력의 한 달. `month` 는 1~12 다.
nonisolated struct CalendarMonth: Hashable, Sendable {
    let year: Int
    let month: Int

    var daysInMonth: Int {
        let calendar = Self.gregorian(.gmt)
        return calendar.range(of: .day, in: .month, for: startDate(in: .gmt))?.count ?? 30
    }

    /// 월요일부터 시작하는 달력에서 1일 앞에 비워 둘 칸 수.
    var leadingBlankDays: Int {
        // weekday 는 일요일이 1 이다. 월요일을 0 으로 옮긴다.
        let weekday = Self.gregorian(.gmt).component(.weekday, from: startDate(in: .gmt))
        return (weekday + 5) % 7
    }

    var label: String { "\(year)년 \(month)월" }

    func previous() -> CalendarMonth {
        month == 1 ? CalendarMonth(year: year - 1, month: 12) : CalendarMonth(year: year, month: month - 1)
    }

    func next() -> CalendarMonth {
        month == 12 ? CalendarMonth(year: year + 1, month: 1) : CalendarMonth(year: year, month: month + 1)
    }

    func day(_ day: Int) -> CalendarDay { CalendarDay(year: year, month: month, day: day) }

    /// 이 달 1일 0시. 이보다 이른 글이 나오면 이 달 게시물은 다 받은 것이다.
    func startDate(in timeZone: TimeZone) -> Date {
        Self.gregorian(timeZone).date(from: DateComponents(year: year, month: month, day: 1)) ?? .distantPast
    }

    static func gregorian(_ timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}

nonisolated extension Array where Element == MapPost {
    /// 날짜(1~31)별 칸 사진. 최신순이라 날마다 처음 만나는 사진 게시물이 그날 가장 최신 글이다.
    /// 사진 없는 글만 있는 날은 넣지 않는다.
    func coverPhotos(in month: CalendarMonth, timeZone: TimeZone) -> [Int: URL] {
        var covers: [Int: URL] = [:]
        for post in self {
            guard let date = post.createdAt, let photo = post.imageURLs.first else { continue }
            let day = CalendarDay.of(date, timeZone: timeZone)
            guard day.calendarMonth == month, covers[day.day] == nil else { continue }
            covers[day.day] = photo
        }
        return covers
    }

    /// 받은 순서(최신순)를 그대로 둔다.
    func posts(on day: CalendarDay, timeZone: TimeZone) -> [MapPost] {
        filter { post in post.createdAt.map { CalendarDay.of($0, timeZone: timeZone) == day } ?? false }
    }
}
