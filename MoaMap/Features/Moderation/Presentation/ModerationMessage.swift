import Foundation

/// 신고·차단 결과를 토스트 문구로 바꾼다. 서버 원문은 쓰지 않는다.
nonisolated enum ModerationMessage {
    static let reported = "신고가 접수됐어요"

    static func blocked(nickname: String?) -> String {
        guard let nickname, !nickname.isEmpty else { return "사용자를 차단했어요" }
        return "\(nickname)님을 차단했어요"
    }

    static func reportFailure(_ error: any Error) -> String {
        guard let error = error as? NetworkError else { return reportFallback }
        switch error {
        case .server(code: "PLACE_019", _, _), .server(code: "PLACE_022", _, _),
             .server(code: "MAP_026", _, _), .server(code: "USER_025", _, _):
            return "이미 신고했어요"
        case .server(code: "PLACE_020", _, _), .server(code: "PLACE_021", _, _), .server(code: "MAP_025", _, _):
            return "내 콘텐츠는 신고할 수 없어요"
        case .server(code: "USER_024", _, _):
            return "나 자신은 신고할 수 없어요"
        case .server(code: "PLACE_002", _, _), .server(code: "MAP_002", _, _):
            return "볼 수 없는 콘텐츠예요"
        case .server(code: "MAP_024", _, _):
            return "공식 지도는 신고할 수 없어요"
        case .server(_, statusCode: 404, _):
            return "이미 삭제된 콘텐츠예요"
        case .connection:
            return "네트워크 연결을 확인해주세요"
        default:
            return reportFallback
        }
    }

    static func blockFailure(_ error: any Error) -> String {
        switch error as? NetworkError {
        case .server(code: "USER_026", _, _): "나 자신은 차단할 수 없어요"
        case .server(_, statusCode: 404, _): "탈퇴했거나 없는 사용자예요"
        case .connection: "네트워크 연결을 확인해주세요"
        default: "차단하지 못했어요. 잠시 후 다시 시도해주세요"
        }
    }

    static func unblockFailure(_ error: any Error) -> String {
        if case .connection = error as? NetworkError { return "네트워크 연결을 확인해주세요" }
        return "차단을 해제하지 못했어요. 잠시 후 다시 시도해주세요"
    }

    private static let reportFallback = "신고하지 못했어요. 잠시 후 다시 시도해주세요"
}
