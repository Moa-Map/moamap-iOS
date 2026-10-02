import Foundation

nonisolated enum MapActivityType: Sendable {
    case placeAdded
    case placeRemoved
    case reviewCreated
}

/// 지도에서 일어난 일 한 건. 서버가 로그를 따로 두지 않고 역산해 줘 식별자가 없다.
nonisolated struct MapActivity: Equatable, Sendable {
    let type: MapActivityType
    let occurredAt: Date?
    /// 이름을 못 찾았으면 nil 이다. 표시 문구는 화면이 정한다.
    let actorName: String?
    let actorImageURL: URL?
    let placeID: Int64?
    let placeName: String?
}

/// 커뮤니티 지도의 일반 멤버가 보낸 장소 등록 요청.
nonisolated struct PendingPlace: Identifiable, Equatable, Sendable {
    let id: Int64
    let placeName: String?
    let requesterName: String?
    let requesterImageURL: URL?
    let requestedAt: Date?
}
