import Foundation

nonisolated struct NotificationPageResponse: Decodable, Sendable {
    let content: [NotificationResponse]?
    let last: Bool?
}

/// 알림 한 건. 문구는 서버가 만든다.
nonisolated struct NotificationResponse: Decodable, Sendable {
    let notificationId: Int64
    /// `PLACE_APPROVED`·`MAP_POST_COMMENTED` 등. 앱이 모르는 값이 올 수 있다.
    let type: String?
    let message: String?
    let targetId: Int64?
    /// 대상이 속한 지도.
    let mapId: Int64?
    let read: Bool?
    /// `Z` 가 붙은 UTC 시각.
    let createdAt: String?

    func toDomain() -> UserNotification {
        UserNotification(
            id: notificationId,
            kind: NotificationKind(rawValue: type ?? "") ?? .unknown,
            message: message ?? "",
            targetID: targetId,
            mapID: mapId,
            read: read ?? false,
            createdAt: ServerDateTime.parse(createdAt, timeZone: .gmt)
        )
    }
}
