import Foundation

/// 공중화장실 지도의 마커 한 개. 화장실은 지도의 장소가 아니라 서버가 따로 받아 둔 공공데이터다.
nonisolated struct RestroomMarker: Identifiable, Equatable, Sendable {
    let id: Int64
    let name: String
    let latitude: Double
    let longitude: Double
    /// 「공중화장실」「개방화장실」 같은 분류.
    let category: String?
}

/// 화면 범위로 받은 화장실.
nonisolated struct RestroomMarkers: Equatable, Sendable {
    let restrooms: [RestroomMarker]
    /// 범위 안 화장실이 서버 한도(500곳)를 넘어 일부만 왔는지. 그러면 화면이 확대를 안내한다.
    let truncated: Bool
}

/// 화장실을 받을 지도 범위.
nonisolated struct ViewportBounds: Equatable, Sendable {
    let south: Double
    let west: Double
    let north: Double
    let east: Double
}

/// 화장실 한 곳의 자세한 정보. 칸 수는 비어 오면 0이다.
nonisolated struct RestroomDetail: Equatable, Sendable {
    let id: Int64
    let name: String
    let category: String?
    /// 도로명 주소, 없으면 지번 주소.
    let address: String?
    let openHours: String?
    let openHoursDetail: String?
    let maleToilet: Int
    let maleUrinal: Int
    let maleDisabledToilet: Int
    let maleDisabledUrinal: Int
    let maleChildToilet: Int
    let maleChildUrinal: Int
    let femaleToilet: Int
    let femaleDisabledToilet: Int
    let femaleChildToilet: Int
    let diaperTable: Bool
    let emergencyBell: Bool
    let entranceCctv: Bool
    let managerOrg: String?
    let phone: String?
    /// 공공데이터 기준일 `yyyy-MM-dd`.
    let dataRefDate: String?
}
