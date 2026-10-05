import Foundation

/// GET api/v1/maps/official/restrooms 응답. 화면 범위 안 화장실, 최대 500곳.
nonisolated struct RestroomListResponse: Decodable, Sendable {
    let restrooms: [RestroomMarkerResponse]?
    let truncated: Bool?
}

nonisolated struct RestroomMarkerResponse: Decodable, Sendable {
    let id: Int64?
    let name: String?
    let lat: Double?
    let lng: Double?
    let category: String?
}

/// GET api/v1/maps/official/restrooms/{id} 응답. 행안부 공중화장실 공공데이터 한 건.
nonisolated struct RestroomDetailResponse: Decodable, Sendable {
    let id: Int64?
    let name: String?
    let category: String?
    let roadAddress: String?
    let lotAddress: String?
    // 칸 수. 남녀 × 일반·장애인·어린이 × 대변기·소변기 (여자 소변기는 없다)
    let maleToilet: Int?
    let maleUrinal: Int?
    let maleDisabledToilet: Int?
    let maleDisabledUrinal: Int?
    let maleChildToilet: Int?
    let maleChildUrinal: Int?
    let femaleToilet: Int?
    let femaleDisabledToilet: Int?
    let femaleChildToilet: Int?
    /// 「정시」「24시간」 같은 구분. 실제 시간은 `openHoursDetail`.
    let openHours: String?
    let openHoursDetail: String?
    let diaperTable: Bool?
    let emergencyBell: Bool?
    let entranceCctv: Bool?
    let managerOrg: String?
    let phone: String?
    let dataRefDate: String?
}

/// 공공데이터에 이름이 빠진 행이 있다. 마커와 카드가 빈 글자로 뜨지 않게 채운다.
private nonisolated let unnamedRestroom = "이름 없는 화장실"

nonisolated extension RestroomListResponse {
    func toDomain() -> RestroomMarkers {
        RestroomMarkers(restrooms: (restrooms ?? []).compactMap { $0.toDomain() }, truncated: truncated ?? false)
    }
}

nonisolated extension RestroomMarkerResponse {
    /// 식별자나 좌표가 없으면 찍을 수 없어 버린다.
    func toDomain() -> RestroomMarker? {
        guard let id, let lat, let lng else { return nil }
        return RestroomMarker(id: id, name: name.nonBlank ?? unnamedRestroom, latitude: lat, longitude: lng, category: category.nonBlank)
    }
}

nonisolated extension RestroomDetailResponse {
    func toDomain(id fallbackID: Int64) -> RestroomDetail {
        RestroomDetail(
            id: id ?? fallbackID,
            name: name.nonBlank ?? unnamedRestroom,
            category: category.nonBlank,
            address: roadAddress.nonBlank ?? lotAddress.nonBlank,
            openHours: openHours.nonBlank,
            openHoursDetail: openHoursDetail.nonBlank,
            maleToilet: maleToilet ?? 0,
            maleUrinal: maleUrinal ?? 0,
            maleDisabledToilet: maleDisabledToilet ?? 0,
            maleDisabledUrinal: maleDisabledUrinal ?? 0,
            maleChildToilet: maleChildToilet ?? 0,
            maleChildUrinal: maleChildUrinal ?? 0,
            femaleToilet: femaleToilet ?? 0,
            femaleDisabledToilet: femaleDisabledToilet ?? 0,
            femaleChildToilet: femaleChildToilet ?? 0,
            diaperTable: diaperTable == true,
            emergencyBell: emergencyBell == true,
            entranceCctv: entranceCctv == true,
            managerOrg: managerOrg.nonBlank,
            phone: phone.nonBlank,
            dataRefDate: dataRefDate.nonBlank
        )
    }
}

private nonisolated extension Optional<String> {
    var nonBlank: String? {
        guard let trimmed = self?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
