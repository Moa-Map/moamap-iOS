import Foundation

/// 지도 한 건을 받아오는 동안의 상태. 미리보기와 상세 화면이 함께 쓴다.
nonisolated enum MapLoadState: Equatable, Sendable {
    case loading
    case loaded(MapDetail)
    case failed(String)

    var map: MapDetail? {
        if case .loaded(let map) = self { map } else { nil }
    }
}

nonisolated enum MapDetailMessage {
    static let loadFailed = "지도를 불러오지 못했어요"
    static let joinFailed = "지도에 참여하지 못했어요"
    static let leaveFailed = "지도에서 나가지 못했어요"
    static let likeFailed = "하트를 반영하지 못했어요"
    static let likeNeedsJoin = "지도에 참여하면 하트를 누를 수 있어요"

    /// 서버 원문은 내보내지 않는다. 연결 실패만 따로 안내한다.
    static func userMessage(for error: any Error, fallback: String) -> String {
        if case .connection = error as? NetworkError { "네트워크에 연결할 수 없어요" } else { fallback }
    }
}
