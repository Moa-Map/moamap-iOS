@MainActor
protocol CollectionRepository {
    func fetchMyMaps(type: CollectionMapType) async throws -> [MyMap]
    func joinByInviteCode(_ inviteCode: String) async throws
    /// 올린 커버의 주소를 돌려준다. 지도 생성 요청에 담는다.
    func uploadCoverImage(_ image: UploadImage) async throws -> String
    func createMap(_ newMap: NewMap) async throws -> CreatedMap
}
