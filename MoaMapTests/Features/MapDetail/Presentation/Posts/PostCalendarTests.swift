import Foundation
import Testing
@testable import MoaMap

let calendarUTC = TimeZone(identifier: "UTC")!

func utcDate(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
    CalendarMonth.gregorian(calendarUTC).date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
}

func calendarPost(_ id: Int64, _ date: Date?, photo: String? = nil) -> MapPost {
    MapPost(
        id: id, authorID: 2, content: "글\(id)",
        imageURLs: photo.flatMap(URL.init(string:)).map { [$0] } ?? [], placeNames: [], createdAt: date
    )
}

struct PostCalendarTests {
    /// 2026-08-01 토, 2026-09-01 화, 2026-06-01 월, 2026-11-01 일.
    @Test func 일일_앞_빈칸은_월요일부터_센다() {
        #expect(CalendarMonth(year: 2026, month: 8).leadingBlankDays == 5)
        #expect(CalendarMonth(year: 2026, month: 9).leadingBlankDays == 1)
        #expect(CalendarMonth(year: 2026, month: 6).leadingBlankDays == 0)
        #expect(CalendarMonth(year: 2026, month: 11).leadingBlankDays == 6)
    }

    @Test func 달마다_날_수가_다르고_윤년_2월은_29일이다() {
        #expect(CalendarMonth(year: 2026, month: 8).daysInMonth == 31)
        #expect(CalendarMonth(year: 2026, month: 9).daysInMonth == 30)
        #expect(CalendarMonth(year: 2026, month: 2).daysInMonth == 28)
        #expect(CalendarMonth(year: 2028, month: 2).daysInMonth == 29)
        #expect(CalendarMonth(year: 2100, month: 2).daysInMonth == 28)
    }

    @Test func 해가_바뀌는_달_이동() {
        #expect(CalendarMonth(year: 2026, month: 1).previous() == CalendarMonth(year: 2025, month: 12))
        #expect(CalendarMonth(year: 2026, month: 12).next() == CalendarMonth(year: 2027, month: 1))
        #expect(CalendarMonth(year: 2026, month: 8).label == "2026년 8월")
    }

    /// 같은 순간이 UTC 로는 전날일 수 있다.
    @Test func 시각을_시간대_기준_날짜로_바꾼다() {
        let date = utcDate(2026, 8, 12, hour: 20)
        #expect(CalendarDay.of(date, timeZone: calendarUTC) == CalendarDay(year: 2026, month: 8, day: 12))
        #expect(CalendarDay.of(date, timeZone: TimeZone(identifier: "Asia/Seoul")!) == CalendarDay(year: 2026, month: 8, day: 13))
        // 말일 밤은 시간대에 따라 다음 달 1일이 된다.
        let lastNight = utcDate(2026, 8, 31, hour: 20)
        #expect(CalendarDay.of(lastNight, timeZone: TimeZone(identifier: "Asia/Seoul")!) == CalendarDay(year: 2026, month: 9, day: 1))
    }

    @Test func 달의_시작은_시간대의_1일_0시다() {
        let seoul = TimeZone(identifier: "Asia/Seoul")!
        #expect(CalendarMonth(year: 2026, month: 8).startDate(in: calendarUTC) == utcDate(2026, 8, 1, hour: 0))
        #expect(CalendarMonth(year: 2026, month: 8).startDate(in: seoul) == utcDate(2026, 7, 31, hour: 15))
    }

    @Test func 날짜_칸에는_그날_가장_최신_사진_게시물의_사진을_쓴다() {
        let posts = [
            calendarPost(4, utcDate(2026, 8, 12, hour: 18)),
            calendarPost(3, utcDate(2026, 8, 12, hour: 15), photo: "https://cdn/new.jpg"),
            calendarPost(2, utcDate(2026, 8, 12, hour: 9), photo: "https://cdn/old.jpg"),
            calendarPost(1, utcDate(2026, 8, 3), photo: "https://cdn/3rd.jpg")
        ]
        #expect(posts.coverPhotos(in: CalendarMonth(year: 2026, month: 8), timeZone: calendarUTC) == [
            12: URL(string: "https://cdn/new.jpg")!, 3: URL(string: "https://cdn/3rd.jpg")!
        ])
    }

    @Test func 다른_달_게시물과_사진_없는_게시물과_시각_모르는_게시물은_칸을_채우지_않는다() {
        let posts = [
            calendarPost(3, utcDate(2026, 9, 1), photo: "https://cdn/sep.jpg"),
            calendarPost(2, utcDate(2026, 8, 20)),
            calendarPost(1, nil, photo: "https://cdn/unknown.jpg")
        ]
        #expect(posts.coverPhotos(in: CalendarMonth(year: 2026, month: 8), timeZone: calendarUTC).isEmpty)
    }

    @Test func 고른_날의_게시물을_받은_순서대로_모은다() {
        let posts = [
            calendarPost(3, utcDate(2026, 8, 12, hour: 18)),
            calendarPost(2, utcDate(2026, 8, 11)),
            calendarPost(1, utcDate(2026, 8, 12, hour: 9))
        ]
        #expect(posts.posts(on: CalendarDay(year: 2026, month: 8, day: 12), timeZone: calendarUTC).map(\.id) == [3, 1])
    }
}
