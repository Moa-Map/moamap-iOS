@testable import MoaMap

@MainActor
final class RestroomRepositoryStub: RestroomRepository {
    var fetch: (ViewportBounds) async throws -> RestroomMarkers = { _ in RestroomMarkers(restrooms: [], truncated: false) }
    var detail: (Int64) async throws -> RestroomDetail = { id in RestroomDetail.stub(id: id) }
    private(set) var requests: [ViewportBounds] = []
    private(set) var detailRequests: [Int64] = []

    func fetchRestrooms(in bounds: ViewportBounds) async throws -> RestroomMarkers {
        requests.append(bounds)
        return try await fetch(bounds)
    }

    func fetchRestroom(id: Int64) async throws -> RestroomDetail {
        detailRequests.append(id)
        return try await detail(id)
    }
}

extension RestroomDetail {
    static func stub(
        id: Int64 = 1, address: String? = nil, openHours: String? = nil, openHoursDetail: String? = nil,
        maleToilet: Int = 0, maleUrinal: Int = 0, maleDisabledToilet: Int = 0,
        femaleToilet: Int = 0, femaleDisabledToilet: Int = 0,
        diaperTable: Bool = false, emergencyBell: Bool = false, entranceCctv: Bool = false,
        managerOrg: String? = nil, phone: String? = nil, dataRefDate: String? = nil
    ) -> RestroomDetail {
        RestroomDetail(
            id: id, name: "화장실", category: nil, address: address, openHours: openHours, openHoursDetail: openHoursDetail,
            maleToilet: maleToilet, maleUrinal: maleUrinal, maleDisabledToilet: maleDisabledToilet, maleDisabledUrinal: 0,
            maleChildToilet: 0, maleChildUrinal: 0, femaleToilet: femaleToilet, femaleDisabledToilet: femaleDisabledToilet,
            femaleChildToilet: 0, diaperTable: diaperTable, emergencyBell: emergencyBell, entranceCctv: entranceCctv,
            managerOrg: managerOrg, phone: phone, dataRefDate: dataRefDate
        )
    }
}
