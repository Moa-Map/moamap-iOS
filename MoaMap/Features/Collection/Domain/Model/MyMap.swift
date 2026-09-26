import Foundation

/// 모음 탭에 표시하는 내가 참여한 지도.
nonisolated struct MyMap: Identifiable, Equatable, Sendable {
    let id: Int64
    let title: String
    let imageURL: URL?
    let memberCount: Int
    let placeCount: Int
    let official: Bool
    let personal: Bool
}

nonisolated enum CollectionMapType: CaseIterable, Sendable {
    case community
    case `private`
}
