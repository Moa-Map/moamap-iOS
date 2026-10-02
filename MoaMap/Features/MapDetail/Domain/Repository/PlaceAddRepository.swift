@MainActor
protocol PlaceAddRepository {
    /// 한 장이라도 실패하면 던진다. 사진이 빠진 채로 등록되면 알아챌 방법이 없다.
    func uploadPhotos(mapID: Int64, photos: [UploadImage]) async throws -> [String]
    /// 승인 대기가 될지 바로 등록될지는 서버가 정한다.
    func addPlace(mapID: Int64, newPlace: NewPlace) async throws
}
