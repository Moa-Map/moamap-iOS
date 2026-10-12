@MainActor
protocol CollectionRepository {
    /// 내가 정한 순서대로 전부 받는다. 순서 변경은 탭의 지도를 빠짐없이 보내야 해서 한 페이지로는 모자란다.
    func fetchMyMaps(type: CollectionMapType) async throws -> [MyMap]
    /// 탭의 내 지도 전체를 원하는 순서대로 보낸다. 하나라도 빠지면 서버가 `MAP_022` 로 전부 거부한다.
    func updateMapOrder(type: CollectionMapType, mapIDs: [Int64]) async throws
    func joinByInviteCode(_ inviteCode: String) async throws
    /// 올린 커버의 주소를 돌려준다. 지도 생성 요청에 담는다.
    func uploadCoverImage(_ image: UploadImage) async throws -> String
    func createMap(_ newMap: NewMap) async throws -> CreatedMap
    /// 방장·관리자만 할 수 있다.
    func updateMap(mapID: Int64, _ update: MapUpdate) async throws
}
