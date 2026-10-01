import Foundation

/// 탐색 화면 카드에 보여줄 지도 요약.
nonisolated struct MapSummary: Identifiable, Hashable, Sendable {
    let id: Int64
    let title: String
    let imageURL: URL?
    let tags: [String]
    let memberCount: Int
    /// 추천 지도 응답에는 장소 수가 없다.
    let placeCount: Int?
    /// 참여한 지도는 소개를 건너뛰고 바로 상세로 간다. 추천은 늘 참여하지 않은 지도다.
    var joined = false
}

/// 페이지 단위로 받은 지도 목록.
nonisolated struct MapPage: Equatable, Sendable {
    let maps: [MapSummary]
    let isLast: Bool
}

nonisolated enum MapSortOrder: CaseIterable, Identifiable, Sendable {
    case popular
    case latest

    var id: Self { self }
}
