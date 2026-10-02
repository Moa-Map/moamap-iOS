@MainActor
protocol MapDetailRepository {
    /// 제작자 닉네임까지 채워서 돌려준다.
    func fetchMapDetail(mapID: Int64) async throws -> MapDetail
    /// 지도에 등록된 장소 전부. 영역으로 골라 받을 API 가 없어 마커를 그리려면 전량이 필요하다.
    func fetchPlaces(mapID: Int64) async throws -> [MapPlace]
    /// 공개 지도에 참여한다. 프라이빗 지도는 초대 코드로만 합류한다.
    func joinMap(mapID: Int64) async throws
    /// 서버가 OWNER 의 탈퇴는 거절한다.
    func leaveMap(mapID: Int64) async throws
    /// OWNER 만 할 수 있다.
    func deleteMap(mapID: Int64) async throws
    /// 서버가 확정한 상태를 돌려준다.
    func setPlaceLiked(placeID: Int64, liked: Bool) async throws -> PlaceLike
}
