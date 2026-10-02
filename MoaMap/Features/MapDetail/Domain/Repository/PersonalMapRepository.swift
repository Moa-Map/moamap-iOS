/// 가입할 때 자동으로 생기는 "나만의 지도"를 다룬다.
@MainActor
protocol PersonalMapRepository {
    /// 다른 지도의 장소를 나만의 지도에 그대로 담는다. 이미 있으면 서버가 `PLACE_010` 으로 막는다.
    func addPlace(placeID: Int64) async throws
}

/// 가입 직후 서버가 나만의 지도를 아직 만들지 못한 경우다.
nonisolated struct PersonalMapNotFoundError: Error {}
