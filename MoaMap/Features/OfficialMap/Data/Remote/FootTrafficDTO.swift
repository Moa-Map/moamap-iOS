import Foundation
import Turf

/// GET api/v1/maps/official/foot-traffic/areas 응답 항목.
nonisolated struct FootTrafficAreaResponse: Decodable, Sendable {
    let footTrafficAreaCd: String?
    let areaNm: String?
    let lat: Double?
    let lng: Double?
    let boundary: Geometry?

    private enum CodingKeys: String, CodingKey {
        case footTrafficAreaCd, areaNm, lat, lng, boundary
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        footTrafficAreaCd = try container.decodeIfPresent(String.self, forKey: .footTrafficAreaCd)
        areaNm = try container.decodeIfPresent(String.self, forKey: .areaNm)
        lat = try container.decodeIfPresent(Double.self, forKey: .lat)
        lng = try container.decodeIfPresent(Double.self, forKey: .lng)
        // 경계 하나가 깨졌다고 지역 전체를 못 받으면 안 된다. 그 지역만 경계 없이 둔다.
        boundary = try? container.decodeIfPresent(Geometry.self, forKey: .boundary)
    }
}

/// GET api/v1/maps/official/foot-traffic/congestion 응답 항목.
nonisolated struct CongestionResponse: Decodable, Sendable {
    let footTrafficAreaCd: String?
    let congestLvl: String?
    let congestMsg: String?
    let ppltnMin: Int64?
    let ppltnMax: Int64?
    let maleRate: Double?
    let femaleRate: Double?
    let ppltnRate0: Double?
    let ppltnRate10: Double?
    let ppltnRate20: Double?
    let ppltnRate30: Double?
    let ppltnRate40: Double?
    let ppltnRate50: Double?
    let ppltnRate60: Double?
    let ppltnRate70: Double?
}

nonisolated extension FootTrafficAreaResponse {
    /// 코드·이름·좌표가 없으면 지도에 놓을 수 없어 버린다.
    func toDomain(congestion: CongestionResponse?) -> DensityArea? {
        guard let footTrafficAreaCd, let areaNm, !areaNm.isEmpty, let lat, let lng else { return nil }
        return DensityArea(
            code: footTrafficAreaCd, name: areaNm, latitude: lat, longitude: lng,
            boundary: boundary, congestion: congestion?.toDomain()
        )
    }
}

nonisolated extension CongestionResponse {
    func toDomain() -> AreaCongestion {
        let rates: [(AgeGroup, Double?)] = [
            (.under10, ppltnRate0), (.teens, ppltnRate10), (.twenties, ppltnRate20), (.thirties, ppltnRate30),
            (.forties, ppltnRate40), (.fifties, ppltnRate50), (.sixties, ppltnRate60), (.seventiesUp, ppltnRate70)
        ]
        return AreaCongestion(
            level: CongestionLevel(label: congestLvl),
            message: congestMsg,
            populationMin: ppltnMin,
            populationMax: ppltnMax,
            ageRates: Dictionary(uniqueKeysWithValues: rates.compactMap { group, rate in rate.map { (group, $0) } }),
            maleRate: maleRate,
            femaleRate: femaleRate
        )
    }
}
