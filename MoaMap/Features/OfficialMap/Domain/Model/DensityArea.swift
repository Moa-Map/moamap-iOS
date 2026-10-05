import Turf

/// 서울시 혼잡도 레벨. 서버는 한글 문구로 내려준다.
nonisolated enum CongestionLevel: String, CaseIterable, Sendable {
    case relaxed
    case normal
    case slightlyBusy
    case busy
    case unknown

    init(label: String?) {
        self = Self.allCases.first { $0.label == label } ?? .unknown
    }

    var label: String {
        switch self {
        case .relaxed: "여유"
        case .normal: "보통"
        case .slightlyBusy: "약간 붐빔"
        case .busy: "붐빔"
        case .unknown: "정보 없음"
        }
    }
}

/// 선언 순서가 어린 순이다. 비율이 같으면 앞선 쪽을 고른다.
nonisolated enum AgeGroup: CaseIterable, Sendable {
    case under10, teens, twenties, thirties, forties, fifties, sixties, seventiesUp

    var label: String {
        switch self {
        case .under10: "10대 미만"
        case .teens: "10대"
        case .twenties: "20대"
        case .thirties: "30대"
        case .forties: "40대"
        case .fifties: "50대"
        case .sixties: "60대"
        case .seventiesUp: "70대 이상"
        }
    }
}

nonisolated struct PopulationShare: Equatable, Sendable {
    let label: String
    let rate: Double
}

nonisolated struct AreaCongestion: Equatable, Sendable {
    let level: CongestionLevel
    let message: String?
    let populationMin: Int64?
    let populationMax: Int64?
    let ageRates: [AgeGroup: Double]
    let maleRate: Double?
    let femaleRate: Double?

    /// 비율이 가장 높은 연령대. 같으면 더 어린 쪽.
    var dominantAge: PopulationShare? {
        var best: (group: AgeGroup, rate: Double)?
        for group in AgeGroup.allCases {
            guard let rate = ageRates[group] else { continue }
            if rate > best?.rate ?? -.infinity { best = (group, rate) }
        }
        return best.map { PopulationShare(label: $0.group.label, rate: $0.rate) }
    }

    /// 비율이 더 높은 성별. 같으면 여성.
    var dominantGender: PopulationShare? {
        if let maleRate, maleRate > femaleRate ?? -.infinity {
            return PopulationShare(label: "남성", rate: maleRate)
        }
        return femaleRate.map { PopulationShare(label: "여성", rate: $0) }
    }
}

/// 유동인구 지역 한 곳. 경계는 지도에 그대로 그리는 GeoJSON 도형이다.
nonisolated struct DensityArea: Identifiable, Equatable, Sendable {
    let code: String
    let name: String
    let latitude: Double
    let longitude: Double
    let boundary: Geometry?
    /// 지역 목록에는 있지만 혼잡도가 아직 집계되지 않았을 수 있다.
    let congestion: AreaCongestion?

    var id: String { code }
}
