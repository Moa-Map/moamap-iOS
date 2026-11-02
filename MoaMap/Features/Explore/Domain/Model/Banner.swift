import Foundation

/// 홈 맨 위 배너 한 장. 문구·버튼은 이미지 안에 들어 있다.
nonisolated struct Banner: Identifiable, Hashable, Sendable {
    let id: Int64
    let imageURL: URL
}
