import Foundation

/// 지도에 참여한 사람 한 명. 역할은 서버 값을 그대로 옮기고, 무엇을 감출지는 화면이 정한다.
nonisolated struct MapMember: Identifiable, Equatable, Sendable {
    let id: Int64
    let name: String
    let imageURL: URL?
    var role: MapRole
    /// 등록해 승인된 장소 수. 서버가 세지 못했으면 nil 이다. 0 으로 채우면 틀린 값이 된다.
    var placeCount: Int?
}
