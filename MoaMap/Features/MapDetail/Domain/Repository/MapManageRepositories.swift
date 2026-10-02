@MainActor
protocol MapActivityRepository {
    /// 최신 순 한 페이지. 지도 멤버가 아니면 서버가 `PLACE_002` 로 막는다.
    func fetchActivities(mapID: Int64) async throws -> [MapActivity]
}

@MainActor
protocol PendingPlaceRepository {
    /// 방장·관리자만 볼 수 있다.
    func fetchPendingPlaces(mapID: Int64) async throws -> [PendingPlace]
    func approve(placeID: Int64) async throws
    func reject(placeID: Int64) async throws
}
