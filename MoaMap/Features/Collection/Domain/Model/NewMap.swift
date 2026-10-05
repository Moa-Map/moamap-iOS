import Foundation

nonisolated enum MapVisibility: Equatable, Sendable {
    case `public`
    case `private`
}

/// 새로 만들 지도. `imageURL` 은 커버 업로드를 마치고 받은 주소다.
nonisolated struct NewMap: Equatable, Sendable {
    var name: String
    var description: String
    var visibility: MapVisibility
    var tags: [String]
    var imageURL: String?
}

/// 방금 만든 지도. 초대 코드는 프라이빗 지도에만 발급된다.
nonisolated struct CreatedMap: Equatable, Sendable {
    let id: Int64
    let inviteCode: String?
}
