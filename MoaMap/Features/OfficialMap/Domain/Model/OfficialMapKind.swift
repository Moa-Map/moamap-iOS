import Foundation

/// 장소 목록 대신 전용 화면으로 여는 공식지도.
nonisolated enum OfficialMapKind: CaseIterable, Sendable {
    /// 지역 혼잡도를 칠한다. 소개할 장소가 없어 소개를 건너뛴다.
    case footTraffic
    /// 화면 범위로 화장실을 받아 찍는다. 수만 곳이라 장소 목록으로 받을 수 없다.
    case restroom

    /// 서버가 구분 필드를 주지 않아 이름으로 알아본다(백엔드 시드가 정한 방식). 이름이 바뀌면 같이 바꾼다.
    var name: String {
        switch self {
        case .footTraffic: "유동인구 지도"
        case .restroom: "공중화장실 지도"
        }
    }

    /// 공식지도인지도 함께 본다. 커뮤니티 지도 이름을 같게 지어도 넘어가면 안 된다.
    init?(official: Bool, title: String) {
        guard official, let kind = Self.allCases.first(where: { $0.name == title }) else { return nil }
        self = kind
    }
}
