import Foundation

/// 서버 알림 종류. 모르는 값은 `unknown` 으로 받아 서버 문구만 보여 준다.
nonisolated enum NotificationKind: String, Equatable, Sendable {
    case placeApproved = "PLACE_APPROVED"
    case placeRejected = "PLACE_REJECTED"
    case placeCommented = "PLACE_COMMENTED"
    case mapPostCommented = "MAP_POST_COMMENTED"
    case mapAdminAssigned = "MAP_ADMIN_ASSIGNED"
    case mapOwnerTransferred = "MAP_OWNER_TRANSFERRED"
    case inquiryAnswered = "INQUIRY_ANSWERED"
    case placeReported = "PLACE_REPORTED"
    case reportReceived = "REPORT_RECEIVED"
    case unknown
}

/// 내 알림 한 건. 시스템 `Notification` 과 헷갈리지 않게 이름을 달리했다.
nonisolated struct UserNotification: Equatable, Identifiable, Sendable {
    let id: Int64
    let kind: NotificationKind
    let message: String
    let targetID: Int64?
    let mapID: Int64?
    var read: Bool
    /// 서버 값을 읽지 못했으면 nil 이고 화면은 시각을 빼고 그린다.
    let createdAt: Date?
}

nonisolated struct NotificationPage: Equatable, Sendable {
    let notifications: [UserNotification]
    let isLast: Bool
}
