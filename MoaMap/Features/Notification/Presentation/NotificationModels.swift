import Foundation

/// 알림을 눌렀을 때 갈 곳.
nonisolated enum NotificationDestination: Equatable, Sendable {
    case map(mapID: Int64)
    /// 지도 상세를 열고 그 위에 게시물 상세를 띄운다.
    case post(mapID: Int64, postID: Int64)
}

nonisolated extension UserNotification {
    /// nil 이면 읽음으로만 바꾼다. 장소 반려·문의 답변·신고는 열 화면이 없다.
    var destination: NotificationDestination? {
        switch kind {
        // 지도 알림은 대상이 곧 지도다. 서버가 mapId 를 비워 보내도 targetId 로 간다.
        case .mapAdminAssigned, .mapOwnerTransferred:
            return (mapID ?? targetID).map { .map(mapID: $0) }
        case .placeApproved, .placeCommented:
            return mapID.map { .map(mapID: $0) }
        case .mapPostCommented:
            guard let mapID, let targetID else { return nil }
            return .post(mapID: mapID, postID: targetID)
        case .placeRejected, .inquiryAnswered, .placeReported, .reportReceived, .unknown:
            return nil
        }
    }
}

nonisolated extension NotificationKind {
    /// 카드 왼쪽 아이콘. 그림마다 색이 들어 있어 칠하지 않는다.
    var iconName: String {
        switch self {
        case .placeApproved, .inquiryAnswered: "Icons/checkbox"
        case .placeRejected, .placeReported, .reportReceived: "Icons/alert"
        case .placeCommented, .mapPostCommented: "Icons/edit"
        case .mapAdminAssigned, .mapOwnerTransferred: "Icons/group"
        case .unknown: "Icons/map"
        }
    }
}

/// 알림 시각. 1분 안 「방금」, 1시간 안 「N분 전」, 같은 날 「N시간 전」, 하루 전 날 「어제」,
/// 7일까지 「N일 전」, 그 뒤로 `2026.10.26`. 날은 기기 시간대 기준이다.
nonisolated enum NotificationTimeLabel {
    private static let maxRelativeDays = 7

    static func text(_ date: Date, now: Date, timeZone: TimeZone) -> String {
        // 기기 시계가 서버보다 늦으면 음수가 된다. 「방금」으로 둔다.
        let elapsed = now.timeIntervalSince(date)
        if elapsed < 60 { return "방금" }
        if elapsed < 3600 { return "\(Int(elapsed / 60))분 전" }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case 0: return "\(Int(elapsed / 3600))시간 전"
        case 1: return "어제"
        case ...maxRelativeDays: return "\(days)일 전"
        default:
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = calendar
            formatter.timeZone = timeZone
            formatter.dateFormat = "yyyy.MM.dd"
            return formatter.string(from: date)
        }
    }
}
