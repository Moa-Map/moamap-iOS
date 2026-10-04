import Foundation

/// 서버 공식지도 중 장소 대신 밀집도를 보여주는 유동인구 지도.
nonisolated enum FootTrafficMap {
    /// 서버가 구분 필드를 주지 않아 이름으로 알아본다. 필드가 생기면 그것으로 바꾼다.
    static let name = "유동인구 지도"

    static func matches(title: String) -> Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines) == name
    }
}
