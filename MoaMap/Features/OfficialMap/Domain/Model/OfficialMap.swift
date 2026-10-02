import Foundation

/// 공식지도 목록에 그려지는 지도 한 건. 공중화장실 지도도 서버가 이 목록으로 내려준다.
nonisolated struct OfficialMap: Identifiable, Hashable, Sendable {
    let id: Int64
    let title: String
    let description: String
    let imageURL: URL?
    /// 참여한 지도는 소개를 건너뛰고 바로 상세로 간다.
    let joined: Bool
}
