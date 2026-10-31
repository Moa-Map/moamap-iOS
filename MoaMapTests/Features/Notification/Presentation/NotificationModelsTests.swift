import Foundation
import Testing
@testable import MoaMap

struct NotificationDestinationTests {
    private typealias Stub = NotificationRepositoryStub

    @Test func 지도_알림은_mapId_가_없으면_targetId_로_간다() {
        #expect(Stub.notification(1, kind: .mapAdminAssigned, mapID: 5, targetID: 9).destination == .map(mapID: 5))
        #expect(Stub.notification(1, kind: .mapOwnerTransferred, mapID: nil, targetID: 9).destination == .map(mapID: 9))
    }

    @Test func 장소_승인과_장소_댓글은_그_지도로_간다() {
        #expect(Stub.notification(1, kind: .placeApproved, mapID: 5).destination == .map(mapID: 5))
        #expect(Stub.notification(1, kind: .placeCommented, mapID: 5).destination == .map(mapID: 5))
        #expect(Stub.notification(1, kind: .placeCommented, mapID: nil).destination == nil)
    }

    @Test func 게시글_댓글은_지도와_게시물이_다_있어야_간다() {
        #expect(Stub.notification(1, kind: .mapPostCommented, mapID: 5, targetID: 9).destination == .post(mapID: 5, postID: 9))
        #expect(Stub.notification(1, kind: .mapPostCommented, mapID: nil, targetID: 9).destination == nil)
        #expect(Stub.notification(1, kind: .mapPostCommented, mapID: 5, targetID: nil).destination == nil)
    }

    @Test func 열_화면이_없는_알림은_이동하지_않는다() {
        for kind in [NotificationKind.placeRejected, .inquiryAnswered, .placeReported, .reportReceived, .unknown] {
            #expect(Stub.notification(1, kind: kind).destination == nil)
        }
    }
}

struct NotificationTimeLabelTests {
    private let seoul = TimeZone(identifier: "Asia/Seoul")!
    /// 서울 2026-10-27 15:00.
    private let now = Date(timeIntervalSince1970: 1_793_080_800)

    private func label(secondsAgo: TimeInterval) -> String {
        NotificationTimeLabel.text(now.addingTimeInterval(-secondsAgo), now: now, timeZone: seoul)
    }

    @Test func 한_시간_안은_방금과_분으로_적는다() {
        #expect(label(secondsAgo: 59) == "방금")
        #expect(label(secondsAgo: 60) == "1분 전")
        #expect(label(secondsAgo: 3599) == "59분 전")
    }

    @Test func 기기_시계가_늦어_미래_시각이면_방금이다() {
        #expect(label(secondsAgo: -300) == "방금")
    }

    @Test func 같은_날은_시간으로_적는다() {
        #expect(label(secondsAgo: 3600) == "1시간 전")
        // 서울 0시 정각은 아직 같은 날이다.
        #expect(label(secondsAgo: 15 * 3600) == "15시간 전")
    }

    @Test func 날짜가_바뀌면_어제와_며칠_전으로_적는다() {
        #expect(label(secondsAgo: 15 * 3600 + 1) == "어제")
        #expect(label(secondsAgo: 7 * 86_400) == "7일 전")
    }

    @Test func 일주일이_넘으면_날짜로_적는다() {
        #expect(label(secondsAgo: 8 * 86_400) == "2026.10.19")
    }
}
