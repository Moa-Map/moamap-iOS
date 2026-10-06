@MainActor
protocol PlaceImportRepository {
    /// 인스타그램 캡션을 읽어 서버에 넘긴다. 캡션을 못 읽으면 `PlaceExtractionError` 를 던진다.
    func extractInstagramPlaces(url: String) async throws -> [ImportedPlace]
    /// 지도 공유 링크는 서버가 직접 읽는다.
    func extractMapSharePlaces(url: String) async throws -> [ImportedPlace]
    /// 붙인 사진을 올리고 장소 id 로 찾게 돌려준다. 등록이 실패해 다시 시도할 때 재사용하려고 등록과 나눈다.
    /// - Parameter mapID: 발급 권한 확인용이라 고른 지도 중 아무거나면 된다.
    func uploadPhotos(mapID: Int64, places: [EditedPlace]) async throws -> [String: [String]]
    /// 고른 지도마다 등록하고 결과를 합산한다. 한 지도라도 실패하면 던진다.
    func savePlaces(mapIDs: [Int64], places: [EditedPlace], photoURLs: [String: [String]]) async throws -> PlaceSaveResult
}
